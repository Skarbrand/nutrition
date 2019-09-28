class Recipenewview < Shoes::Widget
	def initialize
		@globals = Shoes.APPS[0].get_globals
		@items = []
		@ingridients = []
		@globals[:database].list_bookmark_ids.each do |id|
			item = @globals[:database].read_ingridient(id)
			item = @globals[:database].read_ingridient_custom(item)
			@items << item.customname
		end
		@name_field = edit_line
		@button_add = button('Add Line')
		@button_save = button('Save')
		@button_save.click do
			if @globals[:database].search_recipe(@name_field.text.encode('UTF-8'))!=nil
				alert('Recipe-Name already in use!')
			else
				if @name_field.text.empty?
					alert('Name can\'t be empty!')
					break
				end
				self.contents.each do |element|
					next if !defined? element.amount
					if element.check_fields == false
						alert('Please fill all fields')
						break
					end
					ingridient = []
					bookmarks = @globals[:database].list_bookmarks
					ingridient << bookmarks[element.customname]
					ingridient << element.amount
					
					@ingridients << ingridient
				end
				#
				debug(@ingridients)
			end
		end
		@button_add.click do
			recipenewline(@items)
		end

	end
end

class Recipenewline < Shoes::Widget
	attr_reader :customname, :amount
	def initialize(items)
		@amount = ''
		flow do
			@ingridient_choser = list_box
			@ingridient_choser.items = items
			@ingridient_choser.change do
				@customname = @ingridient_choser.text
			end
			@ingridient_amount = edit_line width: 50 do
				@amount = @ingridient_amount.text
			end
			para 'g  '
			@ingridient_closer = button('Remove')
			@ingridient_closer.click do
				self.remove
			end
		end
	end
	def check_fields
		result = true
		if @customname == nil or @amount == ''
			result = false
		end
		return result
	end
end

class Searchview < Shoes::Widget
	def initialize
		tempdblink = Shoes.APPS[0].giveultdb
		@search_field = edit_line
		@search_field.text = Shoes.APPS[0].getsearch
		@search_button = button('Search')
		@search_button.style(margin_right: 16)
		@search_button.click do
			Shoes.APPS[0].setsearchpage(0)
			Shoes.APPS[0].setsearch(@search_field.text)
			Shoes.APPS[0].changeState(:searchview)
		end
		@previous_button = button('<')
		@previous_button.state = 'disabled'
		@previous_button.click do
			Shoes.APPS[0].setsearchpage(Shoes.APPS[0].getsearchpage - 1)
			Shoes.APPS[0].changeState(:searchview)
		end
		counter_result = para ''
		counter_result.style(margin_right: 8)
		@next_button = button('>')
		@next_button.state = 'disabled'
		@next_button.click do
			Shoes.APPS[0].setsearchpage(Shoes.APPS[0].getsearchpage + 1)
			Shoes.APPS[0].changeState(:searchview)
		end
		search_results = tempdblink.search_ingridient(Shoes.APPS[0].getsearch, Shoes.APPS[0].getsearchpage)
		search_results[:data].each do |id,name|
			hoverline([[name]], id, :ingridientview)
		end

		counter_pages = (search_results[:count]/100).to_i
		active_results = 0
		active_results = 100*(Shoes.APPS[0].getsearchpage + 1)
		if search_results[:count] <= 100
			active_results = search_results[:count]
		end
		if Shoes.APPS[0].getsearchpage == counter_pages then
			active_results = search_results[:count]-(100*counter_pages)+(100*Shoes.APPS[0].getsearchpage)
		end
		
		counter_result.text = active_results.to_s + '/' + search_results[:count].to_s
		if counter_pages > 0
			if Shoes.APPS[0].getsearchpage != counter_pages
				@next_button.state = nil
			end
			if Shoes.APPS[0].getsearchpage != 0
				@previous_button.state = nil
			end
		end
		#debug(counter_pages)
	end
end

class Bookmarksview < Shoes::Widget
	def initialize
		headline
		tempdblink = Shoes.APPS[0].giveultdb
		tempdblink.list_bookmark_ids.each do |id|
			item = tempdblink.read_ingridient(id)
			item = tempdblink.read_ingridient_custom(item)
			cell = [
				[item.customname],
				[item.price + " €", 'right']
			]
			hoverline(cell, item.id, :ingridientview)
		end
	end
end

class Datatable < Shoes::Widget
	attr_writer :header_rows, :content_rows
	def initialize
		@header_row = []
		@content_rows = []
	end
	def render
		stack do
			flow do
				hoverline
			end
		end
	end
end

class Headline < Shoes::Widget
	def initialize
		flow do
			flow width: 0.5 do
				para strong("Custom Name")
			end
			flow width: 0.5 do
				para strong("Price/100g")
			end
		end
	end
end


class Hoverline < Shoes::Widget
	def initialize(items, stateArgument, stateNew)
		c_width = 1.0 / items.length.to_f
		flow width: 1.0 do
			items.each do |cell_content|
				flow width: c_width do
					if cell_content.length == 1
						line = para cell_content
					else 
						line = para cell_content[0]
						line.align = 'right'
					end
					border black
				end
			end
			border black
			hover do
				border red
			end
			leave do
				border black
			end
			click do
				Shoes.APPS[0].setactiveingridient(stateArgument) if stateNew == :ingridientview
				Shoes.APPS[0].changeState(stateNew)
			end
		end
	end
end

class Ingridientview < Shoes::Widget
	def initialize
		@temphandler = self
		@ingridient_id = Shoes.APPS[0].getactiveingridient
		tempdblink = Shoes.APPS[0].giveultdb
		@content = tempdblink.read_ingridient(@ingridient_id)
		flow do
			@searchline_id = edit_line do
				@ingridient_id = @searchline_id.text
				Shoes.APPS[0].setactiveingridient(@ingridient_id)
				@content = tempdblink.read_ingridient(@ingridient_id)
				refreshview
			end
			@searchline_id.text = @ingridient_id
		end
		@box = stack
		@box_bookmark = stack
		refreshview
	end
	def refreshview
		@box.clear
		@box.singleingridient(@content)
		@box_bookmark.clear
		@box_bookmark.singleingridientuserquestion(@content, @temphandler)
		@box_bookmark.border black, 2
	end
end

class Singleingridientuserquestion < Shoes::Widget
	def initialize(content, handler)
		tempdblink = Shoes.APPS[0].giveultdb
		if content.id!=nil then
			content = tempdblink.read_ingridient_custom(content)
			flow margin_top: 16 do
				para 'User-specific name:'
				@answerName = edit_line width: 350
				@answerName.text = content.shortname
				@answerName.text = content.customname unless content.customname == nil
			end
			flow do
				para 'User-specific price/100g in €:'
				@answerPrice = edit_line width: 50
				@answerPrice.text = content.price unless content.price == nil
			end
			flow margin_bottom: 16, margin_left: 16 do
				@bookmarkadd = button "Bookmark"
				@bookmarkdelete = button "Delete"
			end
			@bookmarkadd.click do
				if tempdblink.check_ingridient_custom(content.id, @answerName.text)==true
					tempdblink.update_ingridient_custom(content.id, @answerPrice.text, @answerName.text)
				else
					alert('Name already in use!')
				end
				handler.refreshview
			end
			@bookmarkdelete.state = 'disabled' if content.customname == nil
			@bookmarkdelete.click do
				tempdblink.delete_ingridient_custom(content.id)
				handler.refreshview
				#refresh doesnt work?
				Shoes.APPS[0].changeState(:ingridientview)
			end
		end
		#return @thabutton
	end
end

class Singleingridient < Shoes::Widget
	def initialize(content)
		if content.id== nil
			tagline "Ingridient-ID not found"
		else
		tagline content.name + ' per 100g:'
		flow margin: 0 do
			content.nutrition.each do |key,value|
				flow width: 256 do
					flow width: 195 do
						para key, size: 'x-small', margin_top: 2, margin_bottom: 2
					end
					para value, size: 'x-small', margin_top: 2, margin_bottom: 2
				end
			end
		end
		end
	end
end

class Optionsview < Shoes::Widget
	def initialize
		tempdblink = Shoes.APPS[0].giveultdb
		tagline "Shown ingridients:"
		flow do
			tempdblink.list_substances.each do |key, value|
				flow width: 297 do
					checkid = check do
						newuserset = 1 - value.userset
						tempdblink.change_substance_userset(value.id, newuserset)
					end
					checkid.checked = true unless value.userset == 0
					para value.tagname + '(' + value.name + ')' + value.userset.to_s, size: 'x-small'
				end
			end
		end
	end
end

class Welcome < Shoes::Widget
	def initialize
		stack do
			title "Welcome to Food-in-Shoes", align: "center", margin_top: "50%"
		end
	end
end
