require 'image_science'

class ImageScience
  # TODO: submit a patch to image_science calling the built-in freeimage functions instead of using these lists
  
  # from freeimage.h
  FIF_UNKNOWN = -1;
	FIF_BMP		  = 0;
	FIF_ICO		  = 1;
	FIF_JPEG	  = 2;
	FIF_JNG		  = 3;
	FIF_KOALA	  = 4;
	FIF_LBM	  	= 5;
	FIF_IFF     = FIF_LBM;
	FIF_MNG		  = 6;
	FIF_PBM		  = 7;
	FIF_PBMRAW	= 8;
	FIF_PCD		  = 9;
	FIF_PCX		  = 10;
	FIF_PGM		  = 11;
	FIF_PGMRAW	= 12;
	FIF_PNG		  = 13;
	FIF_PPM		  = 14;
	FIF_PPMRAW	= 15;
	FIF_RAS		  = 16;
	FIF_TARGA	  = 17;
	FIF_TIFF	  = 18;
	FIF_WBMP	  = 19;
	FIF_PSD		  = 20;
	FIF_CUT		  = 21;
	FIF_XBM		  = 22;
	FIF_XPM		  = 23;
	FIF_DDS		  = 24;
	FIF_GIF     = 25;
  FIF_HDR     = 26;
  FIF_FAXG3   = 27;
  FIF_SGI     = 28;
	
  FILE_TYPES = {
    # from the documentation
  	FIF_BMP		  => 'BMP',
  	FIF_ICO		  => 'ICO',
  	FIF_JPEG	  => 'JPG',
  	FIF_JNG		  => 'JNG',
  	FIF_KOALA	  => 'KOA',
  	FIF_LBM	  	=> 'LBM',
  	FIF_MNG		  => 'MNG',
  	FIF_PBM		  => 'PBM',
  	FIF_PBMRAW	=> 'PBM',
  	FIF_PCD		  => 'PCD',
  	FIF_PCX		  => 'PCX',
  	FIF_PGM		  => 'PGM',
  	FIF_PGMRAW	=> 'PGM',
  	FIF_PNG		  => 'PNG',
  	FIF_PPM		  => 'PPM',
  	FIF_PPMRAW	=> 'PPM',
  	FIF_RAS		  => 'RAS',
  	FIF_TARGA	  => 'TGA',
  	FIF_TIFF	  => 'TIFF',
  	FIF_WBMP	  => 'WBMP',
  	FIF_PSD		  => 'PSD',
  	FIF_CUT		  => 'CUT',
  	FIF_XBM		  => 'XBM',
  	FIF_XPM		  => 'XPM',
  	FIF_DDS		  => 'DDS',
  	FIF_GIF     => 'GIF',
    FIF_HDR     => 'HDR',
    FIF_FAXG3   => 'G3',
    FIF_SGI     => 'SGI'
  }
	
	MIME_TYPES = {
	  # we only list the standardised MIME types here, leaving out any freeimage invented (ie. all the image/freeimage-* values)
  	FIF_BMP		  => 'image/bmp',
  	FIF_ICO		  => 'image/x-icon',
  	FIF_JPEG	  => 'image/jpeg',
  	FIF_MNG		  => 'video/x-mng',
  	FIF_PCD		  => 'image/x-photo-cd',
  	FIF_PCX		  => 'image/x-pcx',
  	FIF_PNG		  => 'image/png',
  	FIF_RAS		  => 'image/x-cmu-raster',
  	FIF_TIFF	  => 'image/tiff',
  	FIF_WBMP	  => 'image/vnd.wap.wbmp',
  	FIF_XBM		  => 'image/x-xbitmap',
  	FIF_XPM		  => 'image/xpm',
  	FIF_GIF     => 'image/gif',
    FIF_FAXG3   => 'image/fax-g3',
    FIF_SGI     => 'image/sgi'
	}
  
  # determines the file format of this image file (represented as an uppercase string).
  # nil if the file type is not known, or if no image has been loaded.
  def file_type
    FILE_TYPES[@file_type]
  end
  
  # determines the MIME type of this image file.
  # nil if the file type is not known, or if no image has been loaded.
  def mime_type
    MIME_TYPES[@file_type]
  end
end