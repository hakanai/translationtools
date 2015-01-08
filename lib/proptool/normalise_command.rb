require 'pathname'
require 'fileutils'

module PropTool
  class NormaliseCommand

    # args[0] - root of directory
    def run(*args)
      dirstr = nil

      #TODO proper usage errors which can be caught to display the usual usage message
      #TODO proper option parser?
      until args.empty?
        arg = args.shift

        if dirstr.nil?
          dirstr = arg
        else
          raise('too many args')
        end
      end

      raise('dir == nil') if dirstr.nil?

      dir = Pathname.new(dirstr)

      Pathname.glob("#{dir}/**/*.properties") do |file|
        if file.to_s =~ /^(.*?)(?:_[a-zA-Z0-9_]+)+(.properties)$/
          templatefile = Pathname.new("#{$1}#{$2}")
          normalise(file, templatefile)
        end
      end
    end

  protected

    def normalise(file, templatefile)
      normalised = Properties.load(templatefile)
      translated = Properties.load(file)
      # Replacing all root strings with localised strings.
      normalised.deep_merge!(translated)
      # Removing any remaining root strings with no localisation.
      normalised.keep_if { |key, value| translated.key?(key) }
      normalised.store(file)
    end

  end
end
