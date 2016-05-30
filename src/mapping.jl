# Type Mapping
@doc """
### Mapping

A type for creating mapping objects needed for creating

**Members**

*  `nctl`   : Array of number of control points in each direction
*  `jkmmax` : Array of number of nodes in each direction
*  `order`  : Array of order of B-splines in each direction
*  `xi`     :
*  `cp_xyz` :
*  `edge_knot` : 3D Array of edge knot vectors. dim1 = Knot vector, dim2 = edge
                 number (1:4), dim3 = direction (di)
*  `edge_param`: 3D array to store edge spacing parameters. dim1 = A or b,
                 dim2 = edge number (1:4), dim3 = direction (di)
*  `aj`   :
*  `dl`   :
*  `knot` : 2D Array of knot vectors. dim1 = knot vector, dim2 = direction
            (xi, eta, zeta)
*  `work` :

"""->

type Mapping
  nctl::Array(Int, 3)   # Number of control points in each of the 3 dimensions
  jkmmax::Array(Int, 3) # Number of nodes in each direction
  order::Array(Int, 3)  # Order of B-spline in each direction

  xi = AbstractArray{AbstractFloat, 4}     # Coordinate values
  cp_xyz = AbstractArray{AbstractFloat, 4} # Cartesian coordinates of control points
  edge_knot = AbstractArray{AbstractFloat, 3}  # edge knot vectors
  edge_param = AbstractArray{AbstractFloat, 3} # edge parameters

  # Working arrays
  aj = AbstractArray{AbstractFloat, 3}
  dl = AbstractArray{AbstractFloat, 2}
  dr = AbstractArray{AbstractFloat, 2}
  knot = AbstractArray{AbstractFloat, 2}
  work = AbstractArray{AbstractFloat, 4}

  function Mapping(ncpts, nnodes, k)

    # Define max_wrk = number of work elements at each control point
    const max_work = 2*6  # 2*n_variables

    nctl[:] = ncpts[:]    # Set number of control points
    jkmmax[:] = nnodes[:] # Set map refinement level in each coordinate direction
    order[:] = k[:]       # Set the order of B-splines

    # Assertion statements to prevent errors
    for i = 1:3
      @assert nctl[i] > 0
      @assert jkmmax[i] > 0
      @assert order[i] > 0
    end

    # Allocate and initialize mapping arrays
    max_order = maximum(order)  # Highest order among 3 dimensions
    max_knot = max_order + maximum(nctl) # Maximum number of knots among 3 dimensions

    xi = zeros(jkmmax[1], jkmmax[2], jkmmax[3], 3)
    cp_xyz = zeros(nctl[1], nctl[2], nctl[3], 3)
    edge_knot = zeros(max_knot, 4, 3)
    knot = zeros(max_knot, 3)
    edge_param = zeros(2,4,3)
    aj = zeros(3, max_order, 3)
    dl = zeros(max_order-1, 3)
    dr = zeros(max_order-1, 3)
    work = zeros(ntcl[1], nctl[2], nctl[3], max_work)

    new(nctl, jkmmax, order, xi, cp_xyz, edge_knot, edge_param, aj, dl, dr,
        knot, work)

  end  # End constructor

end  # End Mapping

@doc """
### calcdXdxi

It calculates th epartial derivative of the mapping (including the 0th order)

(x,y,z) = [x(xi,eta,zeta), y(xi,eta,zeta), z(xi,eta,zeta)]

**Arguments**

*  `map`    : Object of Mapping type
*  `xi`     : Mapping coordinates to be evaluated
*  `jderiv` : Derivative indices. jderi[mdi] = n means take the nth derivative
              in the xi[mdi] direction.
*  `dX`     : Derivative of X w.r.t the 3 dimensions. length = 3

REFERENCE: Carl de Boor, 'Pratical Guide to Splines', pgs 138-149

Notes: (taken from Mapping_Mod.f90)
1) de Boor points out (pg 149) that for many points (as we may
   have) it is faster to compute the piecewise polys and differentiate
   them.  Something to consider for the future.
2) Since direction indices are used for both the physical and
   mathematical coordinates, di will be reserved for the physical
   and mdi for the mathematical coordinates in this function.

"""->
function calcdXdxi(map, xi, jderiv, dX)

  # dX = zeros(AbstractFloat, 3)
  span = zeros(Int, 3)

  for mdi = 1:3
    if jderiv[mdi] >= map.order[mdi]
      return nothing
    end  # End if
  end # End for mdi = 1:3

  # Find the spatially varying knot vector
  calcKnot(map, xi)  # TODO: Need to write a calcKnot

  # Find the span array in all 3 dimensions such that
  # knot(mdi, left(mdi)) <= xi(mdi) <= knot(mdi, left(mdi)+1)
  for mdi = 1:3
    span[mdi] = findSpan(xi[mdi], map, mdi)
  end  # End for mdi = 1:3

  # Calculations involving the knot vectors are independent, so loop through
  # them independently
  km1 = zeros(Int, 3)
  jcmin = zeros(Int, 3)
  jcmax = zeros(Int, 3)
  imk = zeros(Int, 3)
  for mdi = 1:3
    # Store the B-spline coefficients relevant to the knot span index in
    # aj[mdi,1],...,aj[mdi, order] and compute
    # dl[mdi,j] = xi[mdi] - knot[mdi, span-j]
    # dr[mdi,j] = knot[mdi, span+j] - xi[mdi], for all j = 1:order[mdi]-1

    jcmin[mdi] = 1
    imk[mdi] = span[mdi] - map.order[mdi]
    if imk[mdi] < 0
      # We are close to the left end of the knot interval, so some of the aj
      # will be set to 0 later
      jcmin[mdi] = 1 - imk[mdi]
      for j = 1:span[mdi]
        map.dl[j,mdi] = xi[mdi] - map.knot[span[mdi]+1-j,mdi]
      end # End for j = 1:span[mdi]
      for j = span[mdi]:(map.order[mdi]-1)
        map.dl[j,mdi] = map.dl[span[mdi], mdi]
      end  # End for j = span[mdi]:(map.order[mdi]-1)
    else
      for j = 1:(map.order[mdi]-1)
        map.dl[j,mdi] = xi[mdi] - map.knot[span[mdi]+1-j, mdi]
      end  # End for j = 1:(map.order[mdi]-1)
    end  # End if imk[mdi] < 0

    jcmax[mdi] = map.order[mdi]
    n = map.nctl[mdi]
    nmi = n - span[mdi]
    if nmi < 0
      # We are close to the right end of the knot interval, so some of the aj
      # will be set to 0 later
      jcmax[mdi] = map.order[mdi] + nmi
      for j = 1:jcmax[mdi]
        map.dr[j,mdi] = map.knot[span[mdi]+j, mdi] - xi[mdi]
      end  # End for j = 1:jcmax[mdi]
      for j = jcmax[mdi]:(map.order[mdi]-1)
        map.dr[j,mdi] = map.dr[jcmax[mdi], mdi]
      end
    else
      for j = 1:(map.order[mdi]-1)
        map.dr[j,mdi] = map.knot[span[mdi]+j, mdi] - xi[mdi]
      end  # End for j = 1:(map.order[mdi]-1)
    end  # end if nmi < 0
  end  # End for mdi = 1:3

  # Set all elements of aj[:,:,1] to zero, in case we are close to the ends of
  # the knot vector
  fill!(map.aj[:,:,1], 0.0)

  for jc1 = jcmin[1]:jcmax[1]
    p = imk[1] + jc[1]

    # Set all elements of aj[:,:,2] to zero, in case we are close to the ends of
    # the knot vector
    fill!(map.aj[:,:,2], 0.0)

    for jc2 = jcmin[2]:jcmax[2]
      q = imk[2] + jc2
      # Set all elements of aj[:,:,3] to zero, in case close to the ends of
      # the knot vector
      fill!(map.aj[:,:,3], 0.0)

      for jc3 = jcmin[3]:jcmax[3]
        map.aj[:,jc3,3] = map.cp_xyz[p,q,imk[3]+jc3,:]
      end  # End for jc3 = jcmin[3]:jcmax[3]

      if jderiv[3] != 0
        # derivative: apply the recursive formula X.12b from de Boor
        for j = 1:jderiv[3]
          kmj = map.order[3] - j
          ilo = kmj
          for jj = 1:kmj
            map.aj[:,:,3] = ( map.aj[:,jj+1,3] - map.aj[:,jj,3] ) * kmj /
                            ( map.dl[ilo,3] + map.dr[jj,3] )
            ilo -= 1
          end  # End for jj = 1:kmj
        end    # End for j = 1:jderiv[3]
      end      # End if jderiv[3] != 0

      if jderiv[3] != map.order[3]-1
        # if jderiv != order-1, apply recursive formula from de Boor
        for j = (jderiv[3]+1):(map.order[3]-1)
          kmj = map.order[3] - j
          ilo = kmj
          for jj = 1:kmj
            map.aj[:,jj,3] = ( map.aj[:,jj+1,3]*map.dl[ilo,3] +
                               map.aj[:,jj,3]*map.dr[jj,3] ) /
                               ( map.dl[ilo,3] + map.dr[jj,3] )
            ilo -= 1
          end # End for jj = 1:kmj
        end   # End for j = (jderiv[3]+1):(map.order[3]-1)
      end     # End if jderiv[3] != map.order[3]-1

      map.aj[:,jc2,2] = map.aj[:,1,3]
    end  # End for jc2 = jcmin[2]:jcmax[2], get next element of aj[:,2]

    if jderiv[2] != 0
      # derivative : apply the recursive formula X.12b from de Boor
      for j = 1:jderiv[2]
        kmj = map.order[2] - j
        ilo = kmj
        for jj = 1:kmj
          map.aj[:,jj,2] = ( map.aj[:,jj+1,2] - map.aj[:,jj,2] ) * kmj /
                           ( map.dl[ilo,2] + map.dr[jj,2] )
          ilo -= 1
        end  # End for jj = 1:kmj
      end  # End for j = 1:jderiv[2]
    end  # End if jderiv[2] != 0

    if jderiv[2] != map.order[2]-1
      # if jderiv != order-1, apply recursive formula
      for j = (jderiv[2]+1):(map.order[2]-1)
        kmj = map.order[2] - j
        ilo = kmj
        for jj = 1:kmj
          map.aj[:,jj,2] = ( map.aj[:,jj+1,2]*map.dl[ilo,2] +
                            map.aj[:,jj,2]*map.dr[jj,2] ) / ( map.dl[ilo,2] +
                            map.dr[jj,2] )
          ilo -= 1
        end  # End for jj = 1:kmj
      end  # End for j = (jderiv[2]+1):(map.order[2]-1)
    end  # End if jderiv[2] != map.order[2]-1

    map.aj[:,jc1,1] = map.aj[:,1,2]
  end  # End for jc1 = jcmin[1]:jcmax[1], get next element of map.aj[:,:,1]

  if jderiv[1] != 0
    # derivative : apply the recursive formula X.12b from de Boor
    for j = 1:deriv[1]
      kmj = map.order[1] - j
      ilo = kmj
      for jj = 1:kmj
        map.aj[:,jj,1] = ( map.aj[jj+1,1] - map.aj[:,jj,1] ) * kmj /
                         ( map.dl[ilo,1] + map.dr[jj,1] )
        ilo -= 1
      end  # End for jj = 1:kmj
    end  # End for j = 1:deriv[1]
  end  # End if jderiv[1] != 0

  if jderiv[1] != map.order[1]-1
    # Apply recursive formula as before
    for j = (jderiv[1]+1):(map.order[1]-1)
      kmj = map.order[1] - j
      ilo = kmj
      for jj = 1:kmj
        map.aj[:,jj,1] = ( map.aj[:,jj+1,1]*map.dl[ilo,1] + map.aj[:,jj,1]*
                          map.dr[jj,1] ) / ( map.dl[ilo,1] + map.dr[jj,1] )
        ilo -= 1
      end # End for jj = 1:kmj
    end # End for j = (jderiv[1]+1):(map.order[1]-1)
  end  # End if jderiv[1] != map.order[1]-1

  dX[:] = map.aj[:,1,1]

  return nothing
end  # End function calcdXdxi(map, xi, jderiv)

@doc """
### calcJacobian

Calculates the metric Jacobian value based on the B-spline explicit mapping.

**Arguments**

*  `map`  : Object of Mapping type
*  `Jac`  : Array of mesh Jacobians in j,k,m format

"""->

function calcJacobian(map, Jac)

  return nothing
end
