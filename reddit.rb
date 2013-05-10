require 'cgi'
require 'date'
require 'json'
require 'rest_client'

$domain = 'http://www.reddit.com'
$user_agent = 'Nuzba v0.0.1'

class Reddit
  def initialize(subreddits=['all'])
    @subreddits = subreddits.kind_of?(Array) ? subreddits : [subreddits]
  end

  def entries(options={})
    sort = options[:sort] || 'top'
    t = options[:t] || 'day'
    limit = options[:limit] || 25

    url = "#{$domain}/r/#{@subreddits.join '+'}/#{sort}.json" + 
        "?t=#{t}&limit=#{limit}"
    begin
      res = RestClient.get(url, 'user-agent' => $user_agent)
      data = JSON.parse(res)
    rescue JSON::ParserError, RestClient::GatewayTimeout
      return []
    end
    data['data']['children'].map do |child|
      Entry.new child['data']
    end
  end
end

class Entry
  attr_accessor :title, :url, :permalink, :comments, :date, :votes
  def initialize(hash)
    @date = DateTime.strptime(hash['created_utc'].to_s, '%s')
    @title = CGI.unescapeHTML(hash['title'])
    @votes = hash['score']
    @comments = hash['num_comments']
    @url = hash['url']
    @permalink = $domain + hash['permalink']
  end
end
