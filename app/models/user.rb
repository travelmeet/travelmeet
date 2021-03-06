class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable

  validate :must_accept_terms

  has_many :trips

  BOX_SIZE_IN_METERS = 30000

  SEX_COLLECTION = ['Male', 'Female']
  RELATIONSHIP_STATUS_COLLECTION = ['Single', 'In a relationship']
  MOOD_COLLECTION = ['Hippie', 'Cool', 'Chic']
  TIME_COLLECTION = ['Day', 'Night', 'All day']

  def must_accept_terms

    if is_profile_completed and not accepts
      errors.add(:accepts, "Please accept our Terms of Service")
    end

  end


  def self.find_for_facebook_oauth(auth)

    user = User.where(:provider => auth.provider, :uid => auth.uid).first

    if not user
      user = User.where(:email => auth.info.email).first # Email must be unique so we handle this edge case
    end

    if not user
      user = User.new
      user.provider = auth.provider
      user.uid = auth.uid
      user.password = Devise.friendly_token[0,20] # set a random password, password flow never used by user
    end

    user.email = auth.info.email unless user.is_email_overridden
    user.facebook_token = auth.credentials.token
    user.facebook_token_expires = Time.at(auth.credentials.expires_at)

    user.save!
    user

  end

  def after_facebook_auth

    if self.facebook_token_expires < Time.now
      Rails.logger.error "Token expired for user #{self.id} (expired at #{self.facebook_token_expires})"
      return
    end

    @graph = Koala::Facebook::API.new(self.facebook_token, ENV['FACEBOOK_APP_SECRET'])
    friends = @graph.get_connections("me", "friends")
    friends_uids = friends.collect{|f| f["id"]}

    # Get user profile
    me = @graph.get_object("me", fields: 'birthday,gender,first_name,last_name,location,relationship_status')

    if me['location']
      location_id = me['location']['id']
      location = @graph.get_object(location_id, fields: 'location,name')
      lat = location['location']['latitude']
      long = location['location']['longitude']
      city = location['name']
    else
      lat = nil
      long = nil
      city = nil
    end

    sex = nil
    sex = 'Male' if me['gender'] == 'male'
    sex = 'Female' if me['gender'] == 'female'

    birth_date = Date.strptime(me['birthday'], '%m/%d/%Y') rescue nil
    username = me['user-id']

    first_name = me['first_name']
    last_name = me['last_name']

    relationship_status = nil
    relationship_status = 'Single' if ['Single', 'Widowed', 'Divorced', 'Separated'].include?(me['relationship_status'])
    relationship_status = 'In a relationship' if ['In a relationship', 'Engaged', 'Married', 'In a civil union', 'In a domestic partnership'].include?(me['relationship_status'])
    # manque "It's complicated" et "In an open relationship"

    self.update_attributes!(facebook_friends: friends_uids, latitude: lat, longitude: long, sex: sex, birth_date: birth_date, first_name: first_name, last_name: last_name, relationship_status: relationship_status, city: city)

  end

  def full_name
    "#{first_name.try(:capitalize)} #{last_name.try(:capitalize)}".strip
  end

  def age
    now = Time.now.utc.to_date
    now.year - self.birth_date.year - (self.birth_date.to_date.change(:year => now.year) > now ? 1 : 0)
  end

  def picture_url(width: 100, height: 100)
    "https://graph.facebook.com/#{self.uid}/picture?width=#{width}&height=#{height}"
  end

  def friends
    User.where(:uid => self.facebook_friends)
  end

  def self.find_near_location(latitude, longitude, current_user)

    users_to_consider = ActiveRecord::Base.connection.execute %Q{

      SELECT users.id, users.mood, users.time,
        earth_distance(ll_to_earth(#{ActiveRecord::Base.connection.quote(latitude)}, #{ActiveRecord::Base.connection.quote(longitude)}), ll_to_earth(users.latitude, users.longitude)) AS distance
      FROM users
      WHERE
        (earth_box(ll_to_earth(#{ActiveRecord::Base.connection.quote(latitude)}, #{ActiveRecord::Base.connection.quote(longitude)}), #{BOX_SIZE_IN_METERS}) @> ll_to_earth(users.latitude, users.longitude))
        AND users.id != #{ActiveRecord::Base.connection.quote(current_user.id)}
        AND users.is_profile_completed IS TRUE
    }

    ids_to_properties = {}
    users_to_consider.each {|r|

      if current_user.mood == 'Chic'
        if r['mood'] == 'Chic'
          match_mood = 1
        elsif r['mood'] == 'Cool'
          match_mood = 0.5
        else
          match_mood = 0
        end
      elsif current_user.mood == 'Hippie'
        if r['mood'] == 'Hippie'
          match_mood = 1
        elsif r['mood'] == 'Cool'
          match_mood = 0.5
        else
          match_mood = 0
        end
      else #current_user.mood == 'Cool'
        if r['mood'] == 'Cool'
          match_mood = 1
        elsif r['mood'] == 'Chic'
          match_mood = 0.5
        else
          match_mood = 0
        end
      end

      if current_user.time == 'All day'
        if r['time'] == 'All day'
          match_time = 1
        elsif r['time'] == 'Day'
          match_time = 0.5
        else
          match_time = 0
        end
      elsif current_user.time == 'Day'
        if r['time'] == 'Day'
          match_time = 1
        elsif r['time'] == 'All day'
          match_time = 0.5
        else
          match_time = 0
        end
      else # current_user.time == 'Night'
        if r['time'] == 'Night'
          match_time = 1
        elsif r['time'] == 'All day'
          match_time = 0.5
        else
          match_time = 0
        end
      end

      ids_to_properties[r['id'].to_i] = {
        :distance => r['distance'],
        :mood => r['mood'],
        :time => r['time'],
        :match_mood => match_mood,
        :match_time => match_time
      }

    }

    users = User.where(:id => ids_to_properties.keys).to_a
    users.sort_by! {|user| [-ids_to_properties[user.id][:match_mood], -ids_to_properties[user.id][:match_time], ids_to_properties[user.id][:distance]] }

    return users

  end

  def is_a_friend_of?(other_user)
    return facebook_friends.include? other_user.uid
  end

  def is_a_friend_of_friend_of?(other_user)
    (other_user.facebook_friends & self.facebook_friends).any?
  end

  def male?
    sex == 'Male'
  end

end
