class Version < ActiveRecord::Base
  belongs_to :item, :polymorphic => true
  belongs_to :user
  before_save :set_user_id
  validates_presence_of :event

  named_scope :for_item_type, lambda { |item_types|
    { :conditions => { :item_type => item_types } }
  }

  named_scope :created_after, lambda { |time|
    { :conditions => ['versions.created_at > ?', time] }
  }

  named_scope :by_created_at_ascending, :order => 'versions.created_at asc'

  def reify
    unless object.nil?
      # Attributes

      attrs = YAML::load object

      # Normally a polymorphic belongs_to relationship allows us
      # to get the object we belong to by calling, in this case,
      # +item+.  However this returns nil if +item+ has been
      # destroyed, and we need to be able to retrieve destroyed
      # objects.
      #
      # In this situation we constantize the +item_type+ to get hold of
      # the class...except when the stored object's attributes
      # include a +type+ key.  If this is the case, the object
      # we belong to is using single table inheritance and the
      # +item_type+ will be the base class, not the actual subclass.
      # If +type+ is present but empty, the class is the base class.

      if item
        model = item
      else
        class_name = attrs['type'].blank? ? item_type : attrs['type']
        klass = class_name.constantize
        model = klass.new
      end

      attrs.each do |k, v|
        begin
          model.send "#{k}=", v
        rescue NoMethodError
          logger.warn "Attribute #{k} does not exist on #{item_type} (Version id: #{id})."
        end
      end

      model.reified!
      model
    end
  end

  def next
    Version.first :conditions => ["id > ? AND item_type = ? AND item_id = ?", id, item_type, item_id],
                  :order => 'id ASC'
  end

  def previous
    Version.first :conditions => ["id < ? AND item_type = ? AND item_id = ?", id, item_type, item_id],
                  :order => 'id DESC'
  end

  def index
    Version.all(:conditions => ["item_type = ? AND item_id = ?", item_type, item_id],
                :order => 'id ASC').index(self)
  end
  
  private

  def set_user_id
    self.user_id = self.whodunnit.id if self.whodunnit.is_a?(ActiveRecord::Base)
    return true
  end
end
