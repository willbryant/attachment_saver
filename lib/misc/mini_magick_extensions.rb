require 'mini_magick'

class MiniMagick::Image
  MIME_TYPES = {
    'BMP' => 'image/bmp',
    'CUR' => 'image/x-win-bitmap',
    'DCX' => 'image/dcx',
    'EPDF' => 'application/pdf',
    'EPI' => 'application/postscript',
    'EPS' => 'application/postscript',
    'EPSF' => 'application/postscript',
    'EPSI' => 'application/postscript',
    'EPT' => 'application/postscript',
    'EPT2' => 'application/postscript',
    'EPT3' => 'application/postscript',
    'FAX' => 'image/g3fax',
    'FITS' => 'image/x-fits',
    'G3' => 'image/g3fax',
    'GIF' => 'image/gif',
    'GIF87' => 'image/gif',
    'ICB' => 'application/x-icb',
    'ICO' => 'image/x-win-bitmap',
    'ICON' => 'image/x-win-bitmap',
    'JNG' => 'image/jng',
    'JPEG' => 'image/jpeg',
    'JPG' => 'image/jpeg',
    'M2V' => 'video/mpeg2',
    'MIFF' => 'application/x-mif',
    'MNG' => 'video/mng',
    'MPEG' => 'video/mpeg',
    'MPG' => 'video/mpeg',
    'OTB' => 'image/x-otb',
    'PALM' => 'image/x-palm',
    'PBM' => 'image/pbm',
    'PCD' => 'image/pcd',
    'PCDS' => 'image/pcd',
    'PCL' => 'application/pcl',
    'PCT' => 'image/pict',
    'PCX' => 'image/x-pcx',
    'PDB' => 'application/vnd.palm',
    'PDF' => 'application/pdf',
    'PGM' => 'image/x-pgm',
    'PICON' => 'image/xpm',
    'PICT' => 'image/pict',
    'PJPEG' => 'image/pjpeg',
    'PNG' => 'image/png',
    'PNG24' => 'image/png',
    'PNG32' => 'image/png',
    'PNG8' => 'image/png',
    'PNM' => 'image/pbm',
    'PPM' => 'image/x-ppm',
    'PS' => 'application/postscript',
    'PSD' => 'image/x-photoshop',
    'PTIF' => 'image/x-ptiff',
    'RAS' => 'image/ras',
    'SGI' => 'image/sgi',
    'SUN' => 'image/ras',
    'SVG' => 'image/svg+xml',
    'SVGZ' => 'image/svg',
    'TEXT' => 'text/plain',
    'TGA' => 'image/tga',
    'TIF' => 'image/tiff',
    'TIFF' => 'image/tiff',
    'TXT' => 'text/plain',
    'VDA' => 'image/vda',
    'VIFF' => 'image/x-viff',
    'VST' => 'image/vst',
    'WBMP' => 'image/vnd.wap.wbmp',
    'XBM' => 'image/x-xbitmap',
    'XPM' => 'image/x-xbitmap',
    'XV' => 'image/x-viff',
    'XWD' => 'image/xwd',
  }

  # determines the MIME type of this image file.
  # nil if the file type is not known, or if no image has been loaded.
  def mime_type
    MIME_TYPES[format]
  end
  
  # creates an independent copy of the file.
  def dup
    if ::MiniMagick::Image.respond_to?(:read) # v3
      self.class.read(to_blob)
    else # v1
      self.class.from_blob(to_blob, File.extname(path))
    end
  end
end