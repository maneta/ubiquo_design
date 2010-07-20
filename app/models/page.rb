class Page < ActiveRecord::Base
  belongs_to :published, :class_name => 'Page', :foreign_key => 'published_id', :dependent => :destroy
  belongs_to :parent, :class_name => 'Page', :foreign_key => 'parent_id'
  has_many :children, :class_name => 'Page', :foreign_key => 'parent_id'
  has_one :draft, :class_name => 'Page', :foreign_key => 'published_id'
  has_many :blocks, :dependent => :destroy do
     def as_hash
       self.collect{|block|[block.block_type, block]}.to_hash
     end
  end

  before_save :compose_url_name_with_parent_url
  before_create :assign_template_blocks
  after_save :update_modified
  after_destroy :pending_publish_on_destroy_published

  validates_presence_of :name
  validates_presence_of :url_name, :if => lambda{|page| page.url_name.nil?}
  validates_format_of :url_name, :with => /\A[a-z0-9\/\_\-]*\Z/
  validates_uniqueness_of :url_name,
                          :scope => [:published_id],
                          :if => Proc.new { |page| page.pending_publish? },
                          :allow_blank => true
  validates_presence_of :page_template

  named_scope :published,
              :conditions => ["pages.published_id IS NULL AND pages.pending_publish = ?", false]
  named_scope :drafts,
              :conditions => ["pages.published_id IS NOT NULL OR pages.pending_publish = ?", true]

  # Returns the most appropiate published page for that url, raises an
  # Exception if no match is found
  def self.with_url url
    url_name = url.is_a?(Array) ? url.join('/') : url
    page = find_by_url_name(url_name)
    # Try to consider the last portion as the slug
    url_name = returning(url_name.split('/')) do |portions|
      portions.size > 1 ? portions.pop : portions
    end.join('/') unless page

    returning page || find_by_url_name(url_name) do |page|
      raise ActiveRecord::RecordNotFound.new("Page with url '#{url_name}' not found") unless page
    end
  end

  # filters:
  #   :text: String to search in page name
  #
  # options: find_options
  def self.filtered_search(filters = {}, options = {})
    scopes = create_scopes(filters) do |filter, value|
      case filter
        when :text
          { :conditions => ["upper(pages.name) LIKE upper(?)", "%#{value}%"] }
      end
    end

    apply_find_scopes(scopes) do
      find(:all, options)
    end
  end

  def clear_published_page
    published.destroy unless pending_publish?
  end

  def all_blocks_as_hash
    blocks.as_hash
  end

  def publish
    begin
      transaction do
        self.clear_published_page
        published_page = self.clone
        published_page.pending_publish = false
        published_page.save!
        published_page.blocks.destroy_all
        self.blocks.each do |block|
          new_block = block.clone
          new_block.page = published_page
          new_block.save!
          uhook_publish_block_widgets(block, new_block) do |widget, new_widget|
            uhook_publish_widget_asset_relations(widget, new_widget)
          end
        end
        self.update_attributes(:is_modified => false,
                               :pending_publish => false,
                               :published_id => published_page.id)
        published_page.reload
      end
      return true
    rescue Exception => e
      return false
    end
  end

  # if you remove published page copy, draft page will be pending publish again
  def pending_publish_on_destroy_published
    if self.is_published? && self.draft
      self.draft.update_attributes(:pending_publish => true)
    end
  end

  def wrong_widgets_ids
    self.blocks.map(&:widgets).flatten.reject(&:valid?).map(&:id)
  end

  def is_draft?
    published_id? || (!published_id? && pending_publish?)
  end

  def is_published?
    !is_draft?
  end

  def is_linkable?
    #TODO implement this method
    is_published?
  end

  def is_previewable?
    #TODO Implement this method
    false
  end

  def layout
    #TODO Implement this method with Ubiquodesign::structure
    # reading page_template properties
    "main"
  end

  def self.templates
    UbiquoDesign::Structure.get[:page_templates].map(&:keys).flatten rescue []
  end

  def self.blocks(template = nil)
    if template
      UbiquoDesign::Structure.get(:page_template => template.to_sym)[:blocks].map(&:keys).flatten rescue []
    else
      #TODO Implement this method with UbiquoDesign::structure
      raise NotImplementedError
    end
  end

  def available_widgets
    UbiquoDesign::Structure.get(:page_template => page_template)[:widgets].map(&:keys).flatten
  end

  def update_modified(value = true)
    if !self.changes["is_modified"] && self.is_modified? != value
      self.update_attribute(:is_modified, value)
    end
  end

  private

  def compose_url_name_with_parent_url
    if self.parent
      self.url_name = parent.url_name + "/" + url_name.gsub(/^#{parent.url_name}\//, '')
    end
  end

  def assign_template_blocks
    block_types = Page.blocks(self.page_template)
    block_types.each do |block_type|
      self.blocks << Block.create(:block_type => block_type.to_s)
    end
  end

end
