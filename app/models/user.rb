class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, {
    resident: 0,
    volunteer: 1,
    vendor: 2,
    committee_member: 3,
    admin: 4,
    system_admin: 5,
    platform_visitor: 6
  }

  validates :first_name, :last_name, presence: true
  validates :phone, format: { with: /\A[\d\-\(\)\+\s]+\z/, message: "Invalid phone format" }, allow_blank: true

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.present? ? full_name : email
  end

  has_many :owned_festivals, class_name: 'Festival', dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :vendor_applications, dependent: :destroy
  has_many :applied_festivals, through: :vendor_applications, source: :festival
end
