require 'cgi'
require 'open-uri'

class GooglePlacesParser

  API_KEY = Settings.google_places_api_key
  ESTABLISHMENT = Settings.establishment
  ROOT_SEARCH_URL = "https://maps.googleapis.com/maps/api/place/textsearch/json?"
  ROOT_DETAILS_URL = "https://maps.googleapis.com/maps/api/place/details/json?"

  attr_accessor :address, :keywords, :radius
  attr_reader :search_url, :original_search_results, :current_search_results, :end_of_search_results, :next_page_tokens

  def initialize(args = nil)
    @api_key = API_KEY
    @search_url = ROOT_SEARCH_URL
    @radius = Settings.default_radius
    @next_page_tokens = []

    @address, @keywords, @original_search_results, @current_search_results, @end_of_search_results = nil

    if args.present?
      args.each do |k,v|
        instance_variable_set("@#{k}", v) if instance_variables.include?("@#{k}".to_sym) && v.present?
      end
    end
  end

  def search
    build_original_search_url

    execute
  end

  def get_next_page
    return false if @end_of_search_results.present?

    success = build_page_url(@next_page_tokens.last)

    if success
      execute
    else
      return "Error fetching next page..."
    end
  end

  def get_previous_page
    @end_of_search_results = nil
    @next_page_tokens.pop
    @next_page_tokens.pop

    if @next_page_tokens.empty?
      results_json = @original_search_results.present? ? @original_search_results : @current_search_results
      store_results_info(results_json)
      return get_place_names(results_json)
    else
      success = build_page_url(@next_page_tokens.last)

      if success
        execute
      else
        return "Error fetching previous page..."
      end
    end

  end

  def details(place_key)
    build_details_url(place_key)

    execute(false)
  end

  private

  def build_original_search_url
    append_default_parameters

    append_keywords

    append_address

    append_radius

    append_types
  end

  def build_page_url(next_page_token = nil)
    return false if next_page_token == nil && @next_page_tokens.last.nil?

    reset_url

    append_default_parameters

    append_next_page_token(next_page_token)
  end

  def build_details_url(place_key)
    reset_url(false)

    @search_url = append_default_parameters(false) + place_key
  end

  def reset_url(for_search = true)
    @search_url = for_search ? ROOT_SEARCH_URL : ROOT_DETAILS_URL
  end

  def append_default_parameters(for_search = true)
    @search_url += "key=#{Settings.google_places_api_key}" # api key (required)
    @search_url += "&sensor=false&"                        # sensor (required)
    @search_url += for_search ? "query=" : "reference="    # what we're searching (required)
  end

  def append_address
    @search_url += sanitize_string(" near #{@address}")
  end

  def append_keywords
    @search_url += @keywords.blank? ? ESTABLISHMENT : sanitize_string(@keywords + ESTABLISHMENT)
  end

  def append_radius
    @search_url += "&radius=#{@radius}"
  end

  def append_types
    @search_url += "&types=#{Settings.default_type}"
  end

  def append_next_page_token(token)
    @search_url += "&pagetoken=" + token
  end

  def sanitize_string(string)
    CGI.escape(string)
  end

  def get_place_names(results_json)
    results_json["results"].map {|result| result["name"]}
  end

  def store_results_info(results_json)
    next_page_token = results_json["next_page_token"]

    @original_search_results = results_json if @original_search_results.nil?
    @end_of_search_results = results_json if next_page_token.nil?

    @next_page_tokens.push(next_page_token)

    #TODO: What should this return?
  end

  def execute(is_search = true)
    search_uri = URI.parse(URI.encode(@search_url))

    results_json = JSON.parse(open(search_uri).read)

    if is_search
      @current_search_results = results_json
      store_results_info(results_json)
    end

    if results_json.has_key?("status") && results_json["status"] == "OK"
      return get_place_names(results_json)
    else
      return "Execution error: #{results_json["status"]}"
    end
  end
end
