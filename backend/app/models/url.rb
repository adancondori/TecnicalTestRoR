class Url < ApplicationRecord
  has_many :visits, dependent: :destroy

  validates :original_url, presence: true
  validates :short_url, presence: true, uniqueness: { message: "ya está en uso" }
  

  before_validation :generate_short_url, on: :create

  private
  def generate_short_url
    if self.alias.presence
      self.short_url = self.alias
    else
      loop do
        self.token = SecureRandom.alphanumeric(6)
        self.short_url = self.token
        break unless Url.exists?(short_url: self.short_url)
      end
    end

  end
end
