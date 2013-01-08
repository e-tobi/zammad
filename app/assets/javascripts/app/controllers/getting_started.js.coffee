$ = jQuery.sub()

class Index extends App.Controller
  className: 'container getstarted'

  events:
    'submit form':   'submit',
    'click .submit': 'submit',

  constructor: ->
    super

    # set title
    @title 'Get Started'
    @navupdate '#get_started'

    @master_user = 0
#    @render()
    @fetch()

  fetch: ->

    # get data
    App.Com.ajax(
      id:    'getting_started',
      type:  'GET',
      url:   'api/getting_started',
      data:  {
#        view:       @view,
      }
      processData: true,
      success: (data, status, xhr) =>

        # get meta data
        @master_user = data.master_user

        # load group collection
        App.Collection.load( type: 'Group', data: data.groups )

        # render page
        @render()
    )

  render: ->

    # check authentication, redirect to login if master user already exists
    if !@master_user && !@authenticate()
      @navigate '#login'

    @html App.view('getting_started')(
      master_user: @master_user,
    )

    new App.ControllerForm(
      el: @el.find('#form-master'),
      model: App.User,
      required: 'signup',
      autofocus: true,
    )
    new App.ControllerForm(
      el: @el.find('#form-agent'),
      model: App.User,
      required: 'invite_agent',
      autofocus: true,
    )


    if !@master_user
      @el.find('.agent_user').removeClass('hide')

  submit: (e) ->
    e.preventDefault()
    @params = @formParam(e.target)

    # if no login is given, use emails as fallback
    if !@params.login && @params.email
      @params.login = @params.email

    # set invite flag
    @params.invite = true

    # find agent role
    role = App.Collection.findByAttribute( 'Role', 'name', 'Agent' )
    if role
      @params.role_ids = role.id
    else
      @params.role_ids = [0]

    @log 'updateAttributes', @params
    user = new App.User
    user.load(@params)

    errors = user.validate()
    if errors
      @log 'error new', errors
      @formValidate( form: e.target, errors: errors )
      return false

    # save user
    user.save(
      success: (r) =>

        if @master_user
          @master_user = false
          App.Auth.login(
            data: {
              username: @params.login,
              password: @params.password,
            },
            success: @relogin
#            error: @error,
          )
        else

          # rerender page
          @render()
#      error: =>
#        @modalHide()
    )

  relogin: (data, status, xhr) =>
    @log 'login:success', data

    # login check
    App.Auth.loginCheck()

    # add notify
    App.Event.trigger 'notify:removeall'
#      @notify
#        type: 'success',
#        msg: 'Thanks for joining. Email sent to "' + @params.email + '". Please verify your email address.'

    @el.find('.master_user').fadeOut('slow', =>
      @el.find('.agent_user').fadeIn()
    )

App.Config.set( 'getting_started', Index, 'Routes' )
