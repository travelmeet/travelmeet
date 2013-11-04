class SearchController < ApplicationController

  def index

    city = search_params[:city]
    latitude = search_params[:latitude]
    longitude = search_params[:longitude]
    arriving = search_params[:arriving]
    leaving = search_params[:leaving]

    @search_results = SearchResultsFacade.new(city, latitude, longitude, arriving, leaving)
    @search_results.trips_from_friends = Trip.find_from_friends_near(current_user, latitude, longitude)
    @search_results.trips_not_from_friends = Trip.find_not_from_friends_near(current_user, latitude, longitude)

  end

  def create

    city = search_params[:city]
    latitude = search_params[:latitude]
    longitude = search_params[:longitude]
    arriving = search_params[:arriving]
    leaving = search_params[:leaving]

    @search_results = SearchResultsFacade.new(city, latitude, longitude, arriving, leaving)
    @search_results.trips_from_friends = Trip.find_from_friends_near(current_user, latitude, longitude)
    @search_results.trips_not_from_friends = Trip.find_not_from_friends_near(current_user, latitude, longitude)

    trip = Trip.new(search_params)
    current_user.trips << trip
    current_user.save!

    flash[:notice] = "Successfully added this trip to your list"
    render :index

  end


  private

    def search_params
      hash = params.permit(:city, :latitude, :longitude, :arriving, :leaving)
      hash[:arriving] = Date.strptime(hash[:arriving], "%Y-%m-%d")
      hash[:leaving] = Date.strptime(hash[:leaving], "%Y-%m-%d")
      hash
    end

end