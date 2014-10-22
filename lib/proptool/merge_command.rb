require 'pathname'
require 'fileutils'

module PropTool
  class MergeCommand

    # args[0] - root of source directory
    # args[1] - root of destination directory
    def run(*args)
      srcdirstr = nil
      dstdirstr = nil

      srcopts = {}

      #TODO proper usage errors which can be caught to display the usual usage message
      #TODO proper option parser?
      until args.empty?
        arg = args.shift
        if arg =~ /^--source-encoding=(.*)$/
          srcopts[:encoding] = $1
        else
          if srcdirstr.nil?
            srcdirstr = arg
          elsif dstdirstr.nil?
            dstdirstr = arg
          else
            raise('too many args')
          end
        end
      end

      raise('srcdir == nil') if srcdirstr.nil?
      raise('dstdir == nil') if dstdirstr.nil?

      srcdir = Pathname.new(srcdirstr)
      dstdir = Pathname.new(dstdirstr)

      Pathname.glob("#{srcdir}/**/*.properties") do |srcfile|
        dstfile = dstdir.join(srcfile.relative_path_from(srcdir))
        templatefile = if dstfile.to_s =~ /^(.*?)(?:_[a-zA-Z0-9_]+)+(.properties)$/
          Pathname.new("#{$1}#{$2}")
        else
          nil
        end
        merge(srcfile, srcopts, dstfile, templatefile)
      end
    end

  protected

    def merge(srcfile, srcopts, dstfile, templatefile)

      # If there is a file to use as a template, use that, to get the same ordering.
      merged = if (templatefile && templatefile.exist?)
        Properties.load(templatefile)
      else
        Properties.new
      end

      # Then insert any translations which were already present for the locale.
      if dstfile.exist?
        merged.deep_merge!(Properties.load(dstfile))
      end

      # Then 
      #TODO: Maintaining the surrounding structure would be nice too, but difficult.
      srcprops = Properties.load(srcfile, srcopts)
      merged.deep_merge!(srcprops)

      merged.store(dstfile)
    end

  end
end
