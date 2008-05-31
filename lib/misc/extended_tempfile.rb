require 'tempfile'

class ExtendedTempfile < Tempfile
  def initialize(basename, tmpdir = Dir::tmpdir, extension = '')
    @extension = extension
    super(basename, tmpdir)
  end
  
  def make_tmpname(basename, n)
    sprintf('%s.%d.%d.%s', basename, $$, n, @extension)
  end
end