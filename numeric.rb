#require 'rubygems'
#require 'symbolic'

def linspace(start,stop,num = 100)
  step = (stop - start)/(num - 1.0)
  (0..(num-1)).to_a.collect{|n| start + n * step}
end


def nint(func,var,lb,ub,points=1000)
  res = 0
  step = (ub.to_f-lb)/points
  a = lb
  points.times do |i|
    res += step/6.0*(func.subs(var,a).value +
                     4 * func.subs(var,a + step/2).value +
                    func.subs(var,a + step)).value
    a += step
  end
  res
end

def newtons_method(func,vars,guess,accuracy = 0.01)
  if func.is_a?(Array)
    
  else
    val = func.subs(vars,guess).value
    begin
      deriv = func.diff(vars).subs(vars,guess).value
      guess = guess - val/deriv
      val = func.subs(vars,guess).value
    end while Abs[val] > accuracy
    return guess
  end
end