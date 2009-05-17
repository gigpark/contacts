class Contacts
  class Hotmail < Base
    URL                 = "https://login.live.com/login.srf?id=2"
    OLD_CONTACT_LIST_URL = "http://%s/cgi-bin/addresses"
    NEW_CONTACT_LIST_URL = "http://%s/mail/GetContacts.aspx"
    CONTACT_LIST_URL = "http://mobile.live.com/hm/contacts.aspx?bf=100&ts=1&c=to&cf=1%253bfolder.aspx%253ffolder%253d00000000-0000-0000-0000-000000000002&i=0" 
    COMPOSE_URL         = "http://%s/cgi-bin/compose?"
    PROTOCOL_ERROR      = "Hotmail has changed its protocols, please upgrade this library first. If that does not work, report this error at http://rubyforge.org/forum/?group_id=2693"
    PWDPAD = "IfYouAreReadingThisYouHaveTooMuchFreeTime"
    MAX_HTTP_THREADS    = 8
    
  def real_connect
    data, resp, cookies, forward = get(URL)
    old_url = URL
    until forward.nil?
      data, resp, cookies, forward, old_url = get(forward, cookies, old_url) + [forward]
    end
    
    postdata =  "PPSX=%s&PwdPad=%s&login=%s&passwd=%s&LoginOptions=2&PPFT=%s" % [
      CGI.escape(data.split("><").grep(/PPSX/).first[/=\S+$/][2..-3]),
      PWDPAD[0...(PWDPAD.length-@password.length)],
      CGI.escape(login),
      CGI.escape(password),
      CGI.escape(data.split("><").grep(/PPFT/).first[/=\S+$/][2..-3])
    ]
    
    form_url = data.split("><").grep(/form/).first.split[5][8..-2]
    data, resp, cookies, forward = post(form_url, postdata, cookies)
    
    if data.index("The e-mail address or password is incorrect")
      raise AuthenticationError, "Username and password do not match"
    elsif data != ""
      raise AuthenticationError, "Required field must not be blank"
    elsif cookies == ""
      raise ConnectionError, PROTOCOL_ERROR
    end
    
    old_url = form_url
    
    until forward.nil?
      data, resp, cookies, forward, old_url = get(forward, cookies, old_url) + [forward]
    end

    data, resp, cookies, forward = get("http://mail.live.com/mail", cookies)
    until forward.nil?
      data, resp, cookies, forward, old_url = get(forward, cookies, old_url) + [forward]
    end    
            
    @domain = URI.parse(old_url).host
    @cookies = cookies
    rescue AuthenticationError => m
      if @attempt == 1
        retry
      else
        raise m
      end
  end
   
   
  def contacts(options = {})
    if connected?
      url = URI.parse(contact_list_url)
      data, resp, cookies, forward = get( contact_list_url, @cookies )
       
      if resp.code_type != Net::HTTPOK
        raise ConnectionError, self.class.const_get(:PROTOCOL_ERROR)
      end
      @contacts = []
      go = true
      page = 0
      count_per_page = 20
      while(go) do
        go = false
        index = page * count_per_page
        page += 1
        url = URI.parse(get_contact_list_url(index))
        http = open_http(url)
        resp, data = http.get(get_contact_list_url(index),
          "Cookie" => @cookies
        )
        if resp.body.match(/([A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4})/i)
          @contacts = @contacts + resp.body.scan(/([A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4})/i)
          go = true
        end
      end
      
      @contacts.each do |contact|
        contact = contact.to_a
        contact[1] = contact[0]
        contact[0] = nil
      end
      return @contacts 
    end  

  end
 
  def get_contact_list_url(index) 
    "http://mobile.live.com/hm/contacts.aspx?bf=100&ts=1&c=to&cf=1%253bfolder.aspx%253ffolder%253d00000000-0000-0000-0000-000000000002&i=#{index}"
  end
 
  private
    TYPES[:hotmail] = Hotmail
  
  
  
  end
end
