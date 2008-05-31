require 'test/image_fixtures'

class ImageOperations
  def self.original_image
    { :path => ImageFixtures::fixture_path('test.jpg'),
      :content_type => 'image/jpeg',
      :original_filename => 'test.jpg',
      :width => 448,
      :height => 600 }
  end
  
  def self.resize_operations
    {
      :squish1 =>         [:squish, 100, 50],
      :squish2 =>         [:squish, 10, 50],
      
      :scaleby1 =>        [:scale_by, 0.125, 0.125],
      :scaleby2 =>        [:scale_by, 0.5, 1.0],
      
      :scaletosize1 =>    [:scale_to_fit, 200, 300],
      :scaletosize2 =>    [:scale_to_fit, 720, 900],
      :shrinktosize1 =>   [:shrink_to_fit, 200, 300],
      :shrinktosize2 =>   [:shrink_to_fit, 720, 900],
      :expandtosize1 =>   [:expand_to_fit, 200, 300],
      :expandtosize2 =>   [:expand_to_fit, 720, 900],
      :expandtosize3 =>   [:expand_to_fit, 200, 900],
      :expandtosize4 =>   [:expand_to_fit, 720, 300],
      
      :scaletowidth1 =>   [:scale_to_fit, 200, nil],
      :scaletowidth2 =>   [:scale_to_fit, 720, nil],
      :shrinktowidth1 =>  [:shrink_to_fit, 200, nil],
      :shrinktowidth2 =>  [:shrink_to_fit, 720, nil],
      
      :scaletoheight1 =>  [:scale_to_fit, nil, 300],
      :scaletoheight2 =>  [:scale_to_fit, nil, 900],
      :shrinktoheight1 => [:shrink_to_fit, nil, 300],
      :shrinktoheight2 => [:shrink_to_fit, nil, 900],
      
      :scaletocover1 =>   [:scale_to_cover, 200, 300],
      :scaletocover2 =>   [:scale_to_cover, 720, 900],
      
      :coverandcrop1 =>   [:cover_and_crop, 200, 300],
      :coverandcrop2 =>   [:cover_and_crop, 720, 900],
    }
  end
  
  def self.expected_results
    {
      :squish1 =>         [100, 50],
      :squish2 =>         [10, 50],
      
      :scaleby1 =>        [56, 75],
      :scaleby2 =>        [224, 600],
      
      :scaletosize1 =>    [200, 200*600/448],
      :scaletosize2 =>    [900*448/600, 900],
      :shrinktosize1 =>   [200, 200*600/448],
      :shrinktosize2 =>   [448, 600],
      :expandtosize1 =>   [448, 600],
      :expandtosize2 =>   [900*448/600, 900],
      :expandtosize3 =>   [448, 600],
      :expandtosize4 =>   [448, 600],
      
      :scaletowidth1 =>   [200, 200*600/448],
      :scaletowidth2 =>   [720, 720*600/448],
      :shrinktowidth1 =>  [200, 200*600/448],
      :shrinktowidth2 =>  [448, 600],
      
      :scaletoheight1 =>  [300*448/600, 300],
      :scaletoheight2 =>  [900*448/600, 900],
      :shrinktoheight1 => [300*448/600, 300],
      :shrinktoheight2 => [448, 600],
      
      :scaletocover1 =>   [300*448/600, 300],
      :scaletocover2 =>   [720, 720*600/448],
      
      :coverandcrop1 =>   [200, 300],
      :coverandcrop2 =>   [720, 900],
    }
  end
  
  def self.geometry_strings
    {
      '110x50' =>       [:scale_to_fit, 110, 50],
      '209' =>          [:scale_to_fit, 209, 209],
      '91x' =>          [:scale_to_fit, 91, nil],
      'x48' =>          [:scale_to_fit, nil, 48],
      
      '110x50!' =>      [:squish, 110, 50],
      '209!' =>         [:squish, 209, 209],
      '91x!' =>         [:scale_to_fit, 91, nil], # ! flag has no meaning/effect here
      'x48!' =>         [:scale_to_fit, nil, 48], # same
      
      '110.5x50.2%' =>  [:scale_by, 1.105, 0.502],
      '209.84%' =>      [:scale_by, 2.0984, 2.0984],
      '91.0x%' =>       [:scale_by, 0.910, 0.910],
      'x48.%' =>        [:scale_by, 0.480, 0.480],
      
      '110x50>' =>      [:shrink_to_fit, 110, 50],
      '209>' =>         [:shrink_to_fit, 209, 209],
      '91x>' =>         [:shrink_to_fit, 91, nil],
      'x48>' =>         [:shrink_to_fit, nil, 48],
      
      '110x50<' =>      [:expand_to_fit, 110, 50],
      '209<' =>         [:expand_to_fit, 209, 209],
      '91x<' =>         [:expand_to_fit, 91, nil],
      'x48<' =>         [:expand_to_fit, nil, 48],
      
      '110x50#' =>      [:cover_and_crop, 110, 50],
      '91x#' =>         [:cover_and_crop, 91, nil],
      'x48#' =>         [:cover_and_crop, nil, 48],
    }
  end
end