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
        merge(srcfile, srcopts, dstfile)
      end
    end

  protected

    def merge(srcfile, srcopts, dstfile)
      srcprops = Properties.load(srcfile, srcopts)

      merged =
        if dstfile.exist?
          Properties.load(dstfile)
        else
          Properties.new
        end

      # A detail of Ruby (since 1.9) is that hashes remain in original insertion order.
      #TODO: Maintaining the surrounding structure would be nice too, but difficult.
      merged.merge!(srcprops)

      merged.store(dstfile)
    end

  end
end
