class File
  def size # for compatibility with StringIO & Tempfile
    stat.size
  end
end