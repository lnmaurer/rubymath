# encoding: utf-8

if RUBY_VERSION < '1.9'
  H = Symbolic::Constant.new(6.62606896e-34,'h')
  HBAR = Symbolic::Constant.new(1.054571628e-34,'hbar')
else
  HBAR = Symbolic::Constant.new(1.054571628e-34,'ℏ')
  H = Symbolic::Constant.new(6.62606896e-34,'ℎ')
end

KB = Symbolic::Constant.new(1.3806503e-23,'Kb')