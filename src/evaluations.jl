# Evaluations

@doc """
### evalCurve

Determine the value of curve at certain points

**Inputs**

*  `u` : Array of coordinates where the curve needs to be computed
*  `U` : Knot vector
*  `order` : order of B-spline basis functions, (order = p+1)
*  `P` : Array of control points
*  `C` : Resulting curve values

**Outputs**

*  None

SOURCE: The NURBS book 2nd Edition, Algorithm A3.1
      : Gaetan's pyspline/src/eval_curve
"""->

function evalCurve(u, U, order, P, C)

  @assert length(P) + order == length(U)
  p = order - 1  # Degree of B-spline basis function
  nctl = length(P)
  N = Array(Float64, order) # Array of basis functions 1D

  for i = 1:length(u)
    span = findSpan(u[i], U, order, nctl)
    basisFunctions(U, order, u[i], span, N)
    C[i] = 0.0
    for j = 1:order
      C[i] += N[j]*P[span-order+j]
    end  # End for j = 1:p+1
  end    # End for i = 1:length(u)

  return nothing
end

@doc """
### evalVolume

Determine the the coordinates of a point in a 3D volume using B-splines. The
symbol convention used in the function is from the book

"The NURBS book 2nd Edition"

**Arguments**

*  `map` : Object of mapping type
*  `Vol` : (x,y,z) coordinates of the embedded volume within the contol points

"""->

function evalVolume(map, Vol)

  fill!(Vol, 0.0) # Zero out all entries of Vol

  for k = 1:map.numnodes[3]
    for j = 1:map.numnodes[2]
      for i = 1:map.numnodes[1]
        u = map.xi[i,j,k,1]
        v = map.xi[i,j,k,2]
        w = map.xi[i,j,k,3]
        Nu = zeros(map.order[1])
        Nv = zeros(map.order[2])
        Nw = zeros(map.order[3])

        # Work with u
        span = findSpan(u, map.edge_knot[1], map.order[1], map.nctl[1])
        basisFunctions(map.edge_knot[1], map.order[1], u, span, Nu)
        startu = span - map.order[1]

        # work with v
        span = findSpan(u, map.edge_knot[2], map.order[2], map.nctl[2])
        basisFunctions(map.edge_knot[2], map.order[2], v, span, Nv)
        startv = span - map.order[2]

        # work with w
        span = findSpan(u, map.edge_knot[3], map.order[3], map.nctl[3])
        basisFunctions(map.edge_knot[3], map.order[3], w, span, Nw)
        startw = span - map.order[3]

        for ii = 1:map.order[1]
          for jj = 1:map.order[2]
            for kk = 1:map.order[3]
              for idim = 1:map.ndim
                Vol[i,j,k,idim] += Nu[ii]*Nv[jj]*Nw[kk]*
                                map.cp_xyz[startu+ii, startv+jj, startw+kk,idim]
              end
            end  # End for kk = 1:map.order[3]
          end    # End for jj = 1:map.order[2]
        end      # End for ii = 1:map.order[1]
      end  # End for i = 1:map.numnodes[3]
    end    # End for j = 1:map.numnodes[2]
  end      # End for k = 1:map.numnodes[1]

  return nothing
end
