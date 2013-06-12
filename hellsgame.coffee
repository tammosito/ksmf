Players = new Meteor.Collection("players")
Questions = new Meteor.Collection("questions")
Challenges = new Meteor.Collection("challenges")




if Meteor.isServer
		Meteor.publish null, ->
				Meteor.users.find {},
						fields:
								emails: 1
								
if Meteor.isClient
	
	Meteor.startup ->
		filepicker.setKey "ADoKJLa5Qoz6UnmL0IexAz"
		#filepicker.constructWidget document.getElementById("attachment")
		$ ->
			$(document).foundation()


	#Meteor.Router.add "/": "players"
	Meteor.Router.add "/": "home"
	Meteor.Router.add "/notify": "notify"
	Meteor.Router.add "/questions": "questions"
	Meteor.Router.add "/players": "players"
	Meteor.Router.add "/players/search": "search"
	Meteor.Router.add "/challenges": "challenges"
	Meteor.Router.add "/challenge/start/:player_id": (player_id) ->
		Session.set("opponent_id", player_id)
		return "startChallenge"
	Meteor.Router.add "/challenge/active/:challenge_id": (challenge_id) ->
		Session.set("challenge_id", challenge_id)
		return "showChallenge"

	Meteor.Router.filter "requireLogin",
	#only: "home"
	except: "home"

	Meteor.Router.filters requireLogin: (page) ->
		if Meteor.loggingIn()
			"loading"
		else if Meteor.user()
			page
		else
			"login"

	Handlebars.registerHelper "ifCond", (v1, v2, options) ->
		return options.fn(this)  if v1 is v2
		options.inverse this

	Template.questions.helpers 
		questions: ->
			Questions.find()

	Template.players.helpers 
		players: ->
			Meteor.users.find()

	Template.searchResults.helpers 
		players: ->
			search_query = Session.get("search_query", {})
			re = new RegExp(".*"+search_query+".*")
			Meteor.users.find({"emails.address":re},{})

	Template.challenges.helpers 
		challenges: ->
			me = Meteor.user().emails[0].address
			Challenges.find({"$or": [{"player1": me}, {"player2": me}]}, {})
		me: ->
			me = Meteor.user().emails[0].address

	Template.mychallenges.helpers
		challenges: ->
			if Meteor.user()
				me = Meteor.user().emails[0].address
				myChallenges = Challenges.find({"$or": [{"player1": me}, {"player2": me}]}, {}).fetch()
				console.log myChallenges
				myChallenges = _.where(myChallenges, {winner:null})
				console.log myChallenges
				myChallenges.length
			else
				return "bitte einloggen"

	Template.startChallenge.helpers 
		opponent: ->
			Meteor.users.findOne({_id : Session.get("opponent_id")},{})

	Template.showChallenge.helpers 
		opponent: ->
			Meteor.users.findOne({_id : Session.get("opponent_id")},{})
		challenge: ->
			Challenges.findOne(_id : Session.get("challenge_id"),{})

	Template.questions.rendered = ->  
		filepicker.constructWidget document.getElementById('uploadWidget')

	Template.questions.events "change #uploadWidget": (evt) ->
		$('#image-url').val(evt.fpfile.url);
		console.log evt.fpfile.url

	Template.search.events "keyup #js-search-results": (event, template) =>
		search_query = template.find("#js-search-results").value
		if search_query == ""
			#Easteregg: find only players with 1337 in their names if search_query in empty
			search_query = '1337' 
			Session.set("search_query", search_query)
		else
			Session.set("search_query", search_query)


	Template.startChallenge.events "click #js-start-challenge": (event, template) ->
		player1 = Meteor.user().emails[0].address
		player2 = Meteor.users.findOne({_id : Session.get("opponent_id")},{}).emails[0].address
		#get random question
		mycount = Questions.find().count()
		random = Math.floor((Math.random()* mycount)+1)
		questions = Questions.find().fetch()
		question = questions[random-1]

		Challenges.insert
			created_at: new Date().getTime()
			player1: player1
			result1: null
			player2: player2
			result2: null
			question: question
			winner: null

		challenge = Challenges.findOne({},{sort: {created_at: -1}})
		Meteor.Router.to('/challenge/active/' + challenge._id)

	Template.questions.events "click #js-post-question": (event, template) ->
		Questions.insert
			created_at: new Date().getTime()
			question: template.find("#question").value
			result: template.find("#result").value
			image: template.find("#image-url").value

	Template.showChallenge.events "click #js-post-result": (event, template) ->
		result = template.find("#js-result").value
		challenge = Challenges.findOne(_id : Session.get("challenge_id"),{})

		if challenge.player1 == Meteor.user().emails[0].address
			Challenges.update({_id : Session.get("challenge_id")}, $set:{"result1" : result})
		else if challenge.player2 == Meteor.user().emails[0].address
			Challenges.update({_id : Session.get("challenge_id")}, $set:{"result2" : result})
		else
			"oops, something went wrong here."

		challenge = Challenges.findOne(_id : Session.get("challenge_id"),{})

		if challenge.result1? and challenge.result2?
			result = challenge.question.result
			result1 = challenge.result1
			result2 = challenge.result2
			delta1 = result - result1
			delta1 = delta1 * -1 if delta1 < 0
			delta2 = result - result2
			delta2 = delta2 * -1 if delta2 < 0

			console.log 'result: ' + result
			console.log 'delta1: ' + delta1
			console.log 'delta2: ' + delta2


			if delta2 > delta1
				Challenges.update({_id : Session.get("challenge_id")}, $set:{"winner" : challenge.player1})
				console.log 'winner: ' + challenge.player1
			else if delta1 > delta2
				Challenges.update({_id : Session.get("challenge_id")}, $set:{"winner" : challenge.player2})
				console.log 'winner: ' + challenge.player2
			else
				Challenges.update({_id : Session.get("challenge_id")}, $set:{"winner" : "draw"})
				console.log 'winner: draw' 

		Meteor.Router.to('/notify')


