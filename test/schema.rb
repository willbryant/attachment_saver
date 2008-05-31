def add_generic_attachment_columns(t, want_image_columns)
  t.string   :storage_key,         :null => false
  t.string   :content_type,        :null => false
  t.integer  :size,                :null => false
  t.datetime :created_at,          :null => false
  t.datetime :updated_at
  t.integer  :width,               :null => false if want_image_columns
  t.integer  :height,              :null => false if want_image_columns
end

ActiveRecord::Schema.define(:version => 0) do
  create_table :unprocesseds, :force => true do |t|
    t.string   :original_filename, :null => false
    add_generic_attachment_columns(t, false)
  end

  create_table :images, :force => true do |t|
    t.string   :original_filename, :null => false
    add_generic_attachment_columns(t, true)
  end
  
  create_table :derived_images, :force => true do |t|
    t.string   :original_type,     :null => false
    t.integer  :original_id,       :null => false
    t.string   :format_name,       :null => false
    add_generic_attachment_columns(t, true)
  end
  
  create_table :other_images, :force => true do |t| # for testing derived_image owner polymorphism
    t.string   :original_filename, :null => false
    add_generic_attachment_columns(t, true)
  end
  
  create_table :all_in_one_table_images, :force => true do |t|
    t.string   :original_filename # will be null for deriveds
    t.string   :original_type     # will be null for originals
    t.integer  :original_id       # ditto
    t.string   :format_name       # ditto
    add_generic_attachment_columns(t, true)
  end
end