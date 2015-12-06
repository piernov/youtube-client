require 'httpclient'
require 'oga'

username="myuser@gmail.com"
password="mypass"
feed="subscriptions" # subscriptions, recommended


# Init HTTP Client
clnt = HTTPClient.new({:agent_name => ''})
#clnt.set_cookie_store('cookie.dat')


# Perform login
login_url="https://accounts.google.com/ServiceLogin?service=youtube&uilel=3&hl=fr&passive=true&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Fapp%3Ddesktop%26hl%3Dfr%26feature%3Dsign_in_promo%26action_handle_signin%3Dtrue%26next%3D%252Ffeed%252F"+feed

page = clnt.get(login_url, :follow_redirect => true)

doc = Oga.parse_html(page.body)

post_data = {}

doc.xpath('//input').each do |inp|
	set = 0
	name = ""
	value = ""
	inp.attributes.each do |attr|
		if attr.name == "name"
			name = attr.value
			set+=1
		end
		if attr.name == "value"
			value = attr.value
			set+=1
		end
	end
	if set >= 2 then
		post_data[name] = value
	end
end

post_data["Passwd"]=password
post_data["Email"]=username

post_url = doc.xpath('//form/@action').first.value


res = clnt.post(post_url, post_data)
rloc = res.header["Location"].first


# Load the feed page

hpage = clnt.get(rloc, :follow_redirect => true)
doc = Oga.parse_html(hpage.body)


#clnt.save_cookie_store


# Parse vids

cat = {}

def add_vid_to_table(v, t)
	title = v.at_xpath('h3/a/text()').text
	link = v.at_xpath('h3/a/@href').value
	duration = v.at_xpath('h3/span/text()').text
	author = v.at_xpath('div[@class="yt-lockup-byline"]/a/text()').text
	author_link = v.at_xpath('div[@class="yt-lockup-byline"]/a/@href').value

	t << { :title => title, :link => link, :duration => duration, :author => author, :author_link => author_link }
	return t
end


doc.xpath('//div[@id="browse-items-primary"]/ol/li/ol/li/div/div[@class="feed-item-dismissable"]').each do |inp|
	cname = ""
	if feed=="subscriptions" then
		category = inp.at_xpath('div[@class="shelf-title-table"]/div/h2/span[@class="branded-page-module-title-text"]/text()')
		cname = category.text
	end

	shelf="expanded-shelf"
	if feed=="subscriptions" then
		shelf="multirow-shelf"
	end

	path = "div[@class=\"" + shelf + "\"]/ul/li/div//div[@class=\"yt-lockup-dismissable\"]/div[@class=\"yt-lockup-content\"]"

	if shelf == "expanded-shelf" then
		if not cat["Recommendations"] then
			cat["Recommendations"] = []
		end
		v = inp.at_xpath(path)
		add_vid_to_table(v, cat["Recommendations"])
	elsif shelf == "multirow-shelf" then
		list_vids = []
		vids = inp.xpath(path).each do |v|
			add_vid_to_table(v, list_vids)
		end
		cat[cname] = list_vids
	end
end


# Display the vids list

def render_list(cat)
	link_list = []
	c = 1
	cat.each do |k,v|
		puts k
		v.each do |e|
			title = e[:title]
			author = e[:author]
			duration = e[:duration]
			link = e[:link]
			tmp = "    [" + c.to_s + "] " + author + " — " + title
			tmp += " "*(200-tmp.length) # Crappy right alignment for duration
			tmp += duration
			puts tmp
			c+=1
			link_list << { :title => title, :author => author, :link => link }
		end
	end
	return link_list
end


# Prompt

def choose_music(cat)
	link_list = render_list(cat)
	puts "Choose a number from the list or type q to quit."
	inp = gets
	if inp.chomp == 'q' then
		exit(0)
	end
	num = Integer(inp) rescue false
	if num and num <= link_list.length and num > 0 then
		num -= 1
		puts "Playing: " + link_list[num][:author] + " – " + link_list[num][:title]
		ret = system("mpv http://youtube.com/#{link_list[num][:link]} --no-video") # Using mpv with youtube-dl, remove --no-video if you want the video to be rendered
	else
		puts "Invalid input"
	end
	choose_music(cat)
end

choose_music(cat)
