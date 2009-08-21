class ImageFixtures
  def self.fixture_path(filename)
    File.join(File.dirname(__FILE__), 'fixtures', filename)
  end
  
  def self.valid
    { :path => fixture_path('test.jpg'),
      :content_type => 'image/jpeg',
      :original_filename => 'test.jpg',
      :width => 448,
      :height => 600,
      :expected_content_type => 'image/jpeg',
      :expected_extension => 'jpg' }
  end
  
  def self.wrong_extension
    { :path => fixture_path('wrongextension.png'),
      :content_type => 'image/png',
      :original_filename => 'wrongextension.png',
      :width => 448,
      :height => 600,
      :expected_content_type => 'image/jpeg',
      :expected_extension => 'jpg' }
  end
  
  def self.no_extension
    { :path => fixture_path('noextension'),
      :content_type => 'application/octet-stream',
      :original_filename => 'noextension',
      :width => 448,
      :height => 600,
      :expected_content_type => 'image/jpeg',
      :expected_extension => 'jpg' }
  end
  
  def self.empty_extension
    { :path => fixture_path('emptyextension.'),
      :content_type => 'application/octet-stream',
      :original_filename => 'emptyextension.',
      :width => 448,
      :height => 600,
      :expected_content_type => 'image/jpeg',
      :expected_extension => 'jpg' }
  end
  
  def self.corrupt
    { :path => fixture_path('broken.jpg'),
      :content_type => 'image/jpeg',
      :original_filename => 'broken.jpg',
      :expected_content_type => 'image/jpeg',
      :expected_extension => 'jpg' }
  end
  
  def self.non_image_file
    { :path => fixture_path('test.txt'),
      :content_type => 'text/plain',
      :original_filename => 'test.txt',
      :expected_content_type => 'text/plain',
      :expected_extension => 'txt' }
  end
  
  def self.all_readable
    [valid, wrong_extension, no_extension, empty_extension]
  end
  
  def self.all_unreadable
    [corrupt, non_image_file]
  end
end