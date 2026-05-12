require "digest"
require "securerandom"
require "active_support/security_utils"

class ApiKey < ApplicationRecord
  PREFIX_LENGTH = 16
  ENVIRONMENTS = %w[live test].freeze

  belongs_to :account

  attr_reader :plaintext_key

  validates :name, presence: true
  validates :key_prefix, presence: true
  validates :key_digest, presence: true, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  def self.generate!(account:, name:, environment: "live")
    raise ArgumentError, "environment must be one of #{ENVIRONMENTS.join(', ')}" unless ENVIRONMENTS.include?(environment)

    plaintext = "pk_#{environment}_#{SecureRandom.urlsafe_base64(32).tr('-_', 'ab')}"
    record = new(
      account: account,
      name: name,
      key_prefix: plaintext[0, PREFIX_LENGTH],
      key_digest: digest_for(plaintext)
    )
    record.instance_variable_set(:@plaintext_key, plaintext)
    record.save!
    record
  end

  def self.authenticate(token)
    return nil if token.blank?

    prefix = token[0, PREFIX_LENGTH]
    candidate = active.find_by(key_prefix: prefix)
    return nil unless candidate

    expected = candidate.key_digest
    actual = digest_for(token)
    return nil unless ActiveSupport::SecurityUtils.secure_compare(expected, actual)

    candidate
  end

  def self.digest_for(token)
    Digest::SHA256.hexdigest(token)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  def touch_last_used!
    return if last_used_at && last_used_at > 1.minute.ago
    update_column(:last_used_at, Time.current)
  end
end
