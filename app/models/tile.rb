# frozen_string_literal: true

class Tile < ApplicationRecord
  W3W_REGEX = /\A[a-z]+\.[a-z]+\.[a-z]+\z/

  after_initialize :sanitize_w3w

  attr_accessor :map_popup

  belongs_to :plot, optional: true
  has_many :subscriptions, dependent: :restrict_with_exception

  has_many :previous_subscriptions, ->(tile) { where.not(subscriptions: { id: tile.latest_subscription_id }) }, class_name: 'Subscription', inverse_of: :tile, dependent: :nullify
  belongs_to :latest_subscription, class_name: 'Subscription', optional: true
  has_many :post_associations, as: :postable, inverse_of: :postable, dependent: :restrict_with_exception
  has_many :posts, through: :post_associations

  default_scope { order(:id) }

  scope :available, -> { where.missing(:latest_subscription) }
  scope :unavailable, -> { joins(:latest_subscription).distinct } # TODO: where latest_subscription is active?

  validates :southwest, :northeast, presence: true

  validates :w3w, presence: true, format: { with: W3W_REGEX, message: 'format should be a.b.c' }

  auto_strip_attributes :w3w, squish: true

  def to_geojson
    geojson = RGeo::GeoJSON.encode(bounding_box.to_geometry)

    geojson['properties'] ||= {}
    geojson['properties']['available'] = available?
    geojson['properties']['w3w'] = w3w
    geojson['properties']['popupContent'] = popup_content
    geojson['properties']['focussed'] = (map_popup == :w3w)
    geojson['properties']['link'] = Rails.application.routes.url_helpers.tile_path(self)

    geojson.to_json
  end

  def available?
    latest_subscription.nil? || latest_subscription.new_record? # handle display on 'new' screen
  end

  def unavailable?
    !available?
  end

  def popup_content
    return if map_popup.blank?

    return "///#{w3w}" if map_popup == :w3w

    return popup_content_details if map_popup == :view_details_or_unavailable

    raise "Unexpected map_popup type: '#{map_popup}'"
  end

  def popup_content_details
    lines = ["///#{w3w}"]
    lines << if available?
               # NOTE: target="_top" forces ejection from iFrame
               "<a href=\"#{Rails.application.routes.url_helpers.tile_path(self)}\"
                   target=\"_top\"
                   class=\"btn btn-default\">View & Subscribe</a>"
             else
               'Already taken, sorry!'
             end

    lines.join('<br>')
  end

  def w3w_url
    "https://what3words.com/#{w3w}"
  end

  def bounding_box
    RGeo::Cartesian::BoundingBox.create_from_points(southwest, northeast)
  end

  def midpoint
    RGeo::Cartesian::PointImpl.new(RGeo::Cartesian::Factory.new, bounding_box.center_x, bounding_box.center_y)
  end

  def within_plot?(plot)
    plot.polygon.contains?(midpoint)
  end

  def southwest_rounded
    [southwest.x, southwest.y].map { |coord| format('%.6f', coord) }
  end

  def northeast_rounded
    [northeast.x, northeast.y].map { |coord| format('%.6f', coord) }
  end

  def midpoint_rounded
    [midpoint.x, midpoint.y].map { |coord| format('%.6f', coord) }
  end

  def populate_coords
    x = W3wApiService.convert_to_coordinates(w3w)
    populate_coords_from_w3w_response(x)
  end

  def populate_coords_from_w3w_response(w3w_response)
    square = w3w_response.fetch('square')
    sw = square.fetch('southwest')
    ne = square.fetch('northeast')

    self.southwest = "POINT(#{sw.fetch('lng')} #{sw.fetch('lat')})"
    self.northeast = "POINT(#{ne.fetch('lng')} #{ne.fetch('lat')})"
  end

  def sanitize_w3w
    return if w3w.blank?

    self.w3w = w3w.downcase.delete('/').squish
  end

  def viewable_by?(user)
    subscribed_by?(user) || redeemed_by?(user)
  end

  def subscribed_by?(user)
    latest_subscription&.subscriber == user
  end

  def redeemed_by?(user)
    latest_subscription&.redeemer == user
  end

  def relevant_posts
    [self, plot, plot&.project].compact.map { |x| x.posts.published }.flatten.uniq.sort_by(&:published_at)
  end
end
