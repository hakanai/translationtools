require_relative 'lib/proptool/version'

Gem::Specification.new do |gem|  
  gem.authors       = ['Trejkaz']
  gem.email         = ['trejkaz@trypticon.org']
  gem.description   = 'Properties file manipulation tool'
  gem.summary       = 'Helps manipulate properties files for localisation of Java applications'
  #TODO: Rename the repo
  gem.homepage      = 'http://github.com/trejkaz/translationtools'
  gem.files         = `git ls-files`.split($\)
  gem.executables   = ['proptool']
  gem.test_files    = gem.files.grep(/^(test|spec|features)\//)
  gem.name          = 'proptool'
  gem.require_paths = ['lib']
  gem.version       = PropTool::VERSION
end  
