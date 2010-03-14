require 'rubygems'
require 'symbolic'

def linspace(start,stop,num = 100)
  step = (stop - start)/(num - 1.0)
  (0..(num-1)).to_a.collect{|n| start + n * step}
end


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