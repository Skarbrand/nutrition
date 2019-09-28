require 'database.rb'
require 'view.rb'
require 'table.rb'

Shoes.app width:1024 do
	@testdb = Database.new
	@testdb.load_userSettings
	@appState = :welcome
	@activeIngridient = ''
	@search = ''
	@searchpage = 0
	
	def giveultdb
		return @testdb
	end
	
	def getactiveingridient
		return @activeIngridient
	end
	def setactiveingridient(newactiveingridient)
		@activeIngridient = newactiveingridient
	end

	def getsearch
		return @search
	end
	def setsearch(newsearch)
		@search = newsearch
	end
	def getsearchpage
		return @searchpage
	end
	def setsearchpage(newsearchpage)
		@searchpage = newsearchpage
	end
	@global_handles = {
		:database => @testdb,
		:ingridient_active => @activeIngridient,
		:search_string => @search,
		:search_page => @search_page,
	}
	def get_globals
		return @global_handles
	end
	flow do
		@homeButton = button "Main"
		@homeButton.click do
			changeState(:welcome)
		end
		@searchButton = button "Search"
		@searchButton.click do
			changeState(:searchview)
		end
		@ingridientButton = button "Ingridients"
		@ingridientButton.click do
			changeState(:ingridientview)
		end
		@bookmarkButton = button "Bookmarks"
		@bookmarkButton.click do
			changeState(:bookmarksview)
		end
		@recipeNewButton = button "New Recipe"
		@recipeNewButton.click do
			changeState(:recipenewview)
		end
		@optionsButton = button "Usersettings"
		@optionsButton.click do
			changeState(:optionsview)
		end
	end

	@mainBox = stack

	def changeState(newState)
		@appState = newState
		@mainBox.clear
		@mainBox.send(@appState)
	end

	changeState(:welcome)
	#debug(@global_handles[:database].search_recipe('testa'))
end
