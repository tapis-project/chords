class Profile < ActiveRecord::Base

    validates :doi, allow_blank: true, format: {
      with:    /10.\d{4,9}\/[-._;()\/:A-Z0-9]+/i,
      message: "invalid DOI"
    }

  def self.initialize
    Profile.create([{
    project: 'Real-Time Measurements', 
    affiliation: 'My Organization',
    timezone: 'Mountain Time (US & Canada)',
    description: 'This is a CHORDS Portal.
    <ul>
    <li>A CHORDS Portal:</li>
    <ul>
    <li>is simple to create and configure.</li>
    <li>it\'s really easy to post data from sensors into the portal.</li>
    <li>it\'s really easy to get data from the portal into your diverse applications.</li>
    <li>the portal provides a simple but comprehensive view of your complete real-time data system.</li>
    </ul>
    <li>CHORDS Services:</li>
    <ul>
    <li>can connect easily to (many) portals.</li>
    <li>can leverage the real-time streams into other more sophisticated and standardized web services (such as mapping, data federation, and discovery).</li>
    </ul>
    </ul>
    ', 
    logo: nil,
    secure_administration: true,
    data_entry_key: 'key'
    
    }])      
  end

  def self.get_cuahsi_sourceid

    uri = URI.parse("http://hydroportal.cuahsi.org/CHORDS/index.php/default/services/api/GetSourcesJSON")

    request = Net::HTTP::Post.new uri.path

    response = Net::HTTP.start(uri.host, uri.port, :use_ssl => false) do |http|
      response = http.request request
    end

    url = "example.com" #url from profile
    sources = JSON.parse(response.body)
    id = sources.find {|source| source['SourceLink']==url}['SourceID']
    return id
  end

end
