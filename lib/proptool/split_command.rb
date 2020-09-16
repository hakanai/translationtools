module PropTool
  class SplitCommand
    # args[0] - root of source directory
    # args[1] - root of destination directory
    def run(*args)
      srcdirstr = nil
      dstdirstr = nil

      locales = []
      includes = []
      excludes = []
      dstopts = {}

      #TODO proper usage errors which can be caught to display the usual usage message
      #TODO proper option parser?
      until args.empty?
        arg = args.shift
        if arg =~ /^--locales=(.*)$/
          locales = $1.split(',')
        elsif arg =~ /^--include=(.*)$/
          includes << $1
        elsif arg =~ /^--exclude=(.*)$/
          excludes << $1
        elsif arg =~ /^--destination-encoding=(.*)$/
          dstopts[:encoding] = $1
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
        srcpath = srcfile.relative_path_from(srcdir)

        next if excludes.any? { |glob| srcpath.fnmatch?(glob) }
        next if !includes.empty? && !includes.any? { |glob| srcpath.fnmatch?(glob) }

        locale = nil
        dstpath =
          if srcpath.to_s =~ /^(.*?)(?:_([a-zA-Z0-9_]+))(.properties)$/
            prefix, locale, suffix = $1, $2, $3
            "#{locale}/#{prefix}#{suffix}"
          else
            "root/#{srcpath}"
          end

        next if locale && !locales.empty? && !locales.include?(locale)

        dstfile = dstdir.join(dstpath)
        FileUtils.mkdir_p(dstfile.parent)

        properties = Properties.load(srcfile)
        properties.store(dstfile, dstopts)
      end
    end
  end
end
