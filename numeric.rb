require 'rubygems'
require 'symbolic'

# def nint(func,var,lb,ub,points=1000)
#   initval = var.value
#   res = 0
#   step = (ub.to_f-lb)/points
#   a = lb
#   points.times do |i|
#     var.value = a
#     fa = func.value
#     var.value = a + step/2
#     fab = func.value
#     var.value = a + step
#     fb = func.value
#     res += step/6.0*(fa+4*fab+fb)
#     a += step
#   end
#   res
# end


def nint(func,var,lb,ub,points=1000)
  res = 0
  step = (ub.to_f-lb)/points
  a = lb
  points.times do |i|
    res += step/6.0*(func.substitute(var,a) +
                     4 * func.substitute(var,a + step/2) +
                    func.substitute(var,a + step))
    a += step
  end
  res
end