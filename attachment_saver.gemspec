# -*- encoding: utf-8 -*-
require File.expand_path('../lib/attachment_saver/version', __FILE__)

spec = Gem::Specification.new do |gem|
  gem.name         = 'attachment_saver'
  gem.version      = AttachmentSaver::VERSION
  gem.summary      = "Saves attachments in files, models, or columns."
  gem.description  = <<-EOF
This plugin implements attachment storage and processing, integrated with
ActiveRecord models and Ruby CGI/Rails-style uploads.  Image processing
operations including a number of different resizing & thumbnailing modes are
provided, and the architecture simplifies clean implementation of other types
of processing.  Errors are carefully handled to minimize the possibility of
broken uploads leaving incomplete or corrupt data.

RMagick, MiniMagick, and ImageScience image processors are supported.
EOF
  gem.has_rdoc     = false
  gem.author       = "Will Bryant"
  gem.email        = "will.bryant@gmail.com"
  gem.homepage     = "http://github.com/willbryant/attachment_saver"
  gem.license      = 'MIT'
  
  gem.executables  = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files        = `git ls-files`.split("\n")
  gem.test_files   = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.require_path = "lib"
  
  gem.add_dependency "activerecord"
  gem.add_dependency "mimemagic"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "image_science"
  gem.add_development_dependency "rmagick"
  gem.add_development_dependency "mini_magick"
  gem.add_development_dependency "image_size"
  gem.add_development_dependency "gdk_pixbuf2"
  gem.add_development_dependency "sqlite3"
  gem.add_development_dependency "mocha"
end
