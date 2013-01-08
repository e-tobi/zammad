$ = jQuery.sub()

class Index extends App.Controller
  events:
    'click .customer_new': 'userNew'
    'submit form':         'submit'
    'click .submit':       'submit'
    'click .cancel':       'cancel'
    'click .article-type': 'articleTypeSelect'

  constructor: (params) ->
    super

    # check authentication
    return if !@authenticate()

    # set title
    @title 'New Ticket'
    @form_id = App.ControllerForm.formId()
    @navupdate '#ticket_create'

    @edit_form = undefined
    @article_type = 'phone'
    @article_type_map =
      'phone': 'Customer'
      'email': 'Agent'

    @fetch(params)

    # lisen if view need to be rerendert
    App.Event.bind 'ticket_create_rerender', (defaults) =>
      @log 'AgentTicketPhone', 'error', defaults
      @render(defaults)

  # get data / in case also ticket data for split
  fetch: (params) ->

    # use cache
    cache = App.Store.get( 'ticket_create_attributes' )

    if cache && !params.ticket_id && !params.article_id

      # get edit form attributes
      @edit_form = cache.edit_form

      # load user collection
      App.Collection.load( type: 'User', data: cache.users )

      @render()
    else
      App.Com.ajax(
        id:    'ticket_create'
        type:  'GET'
        url:   'api/ticket_create'
        data:
          ticket_id: params.ticket_id
          article_id: params.article_id
        processData: true
        success: (data, status, xhr) =>

          # cache request
          App.Store.write( 'ticket_create_attributes', data )

          # get edit form attributes
          @edit_form = data.edit_form

          # load user collection
          App.Collection.load( type: 'User', data: data.users )

          # load ticket collection
          if data.ticket && data.articles
            App.Collection.load( type: 'Ticket', data: [data.ticket] )

            # load article collections
            App.Collection.load( type: 'TicketArticle', data: data.articles || [] )

            # render page
            t = App.Collection.find( 'Ticket', params.ticket_id ).attributes()
            a = App.Collection.find( 'TicketArticle', params.article_id )

            # reset owner
            t.owner_id = 0
            t.customer_id_autocompletion = a.from
            t.subject = a.subject || t.title
            t.body = a.body
            @log '11111', t
          @render( options: t )
      )

  render: (template = {}) ->

    # set defaults
    defaults = template['options'] || {}
    if !( 'ticket_state_id' of defaults )
      defaults['ticket_state_id'] = App.Collection.findByAttribute( 'TicketState', 'name', 'open' ).id
    if !( 'ticket_priority_id' of defaults )
      defaults['ticket_priority_id'] = App.Collection.findByAttribute( 'TicketPriority', 'name', '2 normal' ).id

    # remember customers
    if $('#create_customer_id').val()
      defaults['customer_id'] = $('#create_customer_id').val()
      defaults['customer_id_autocompletion'] = $('#create_customer_id_autocompletion').val()
    else
#      defaults['customer_id'] = '2'
#      defaults['customer_id_autocompletion'] = '12312313'

    # generate form    
    configure_attributes = [
      { name: 'customer_id',        display: 'Customer', tag: 'autocompletion', type: 'text', limit: 200, null: false, relation: 'User', class: 'span7', autocapitalize: false, help: 'Select the customer of the Ticket or create one.', link: '<a href="" class="customer_new">&raquo;</a>', callback: @localUserInfo },
      { name: 'group_id',           display: 'Group',    tag: 'select',   multiple: false, null: false, filter: @edit_form, nulloption: true, relation: 'Group', default: defaults['group_id'], class: 'span7',  },
      { name: 'owner_id',           display: 'Owner',    tag: 'select',   multiple: false, null: true,  filter: @edit_form, nulloption: true, relation: 'User',  default: defaults['owner_id'], class: 'span7',  },
      { name: 'tags',               display: 'Tags',     tag: 'tag',      type: 'text', null: true, default: defaults['tags'], class: 'span7', },
      { name: 'subject',            display: 'Subject',  tag: 'input',    type: 'text', limit: 200, null: false, default: defaults['subject'], class: 'span7', },
      { name: 'body',               display: 'Text',     tag: 'textarea', rows: 8,                  null: false, default: defaults['body'],    class: 'span7', upload: true },
      { name: 'ticket_state_id',    display: 'State',    tag: 'select',   multiple: false, null: false, filter: @edit_form, relation: 'TicketState',    default: defaults['ticket_state_id'],    translate: true, class: 'medium' },
      { name: 'ticket_priority_id', display: 'Priority', tag: 'select',   multiple: false, null: false, filter: @edit_form, relation: 'TicketPriority', default: defaults['ticket_priority_id'], translate: true, class: 'medium' },
    ]
    @html App.view('agent_ticket_create')(
      head:  'New Ticket'
      agent: @isRole('Agent')
      admin: @isRole('Admin')
    )

    new App.ControllerForm(
      el: @el.find('#form_create')
      form_id: @form_id
      model:
        configure_attributes: configure_attributes
        className:            'create'
      autofocus: true
      form_data: @edit_form
    )

    # send chanel type
    if defaults['article_type']
      @articleTypeSet( defaults['article_type'] )
    else
      @articleTypeSet( @article_type )

    # add elastic to textarea
    @el.find('textarea').elastic()

    # update textarea size
    @el.find('textarea').trigger('change')

    # start customer info controller
    if defaults['customer_id']
      $('#create_customer_id').val( defaults['customer_id'] )
      $('#create_customer_id_autocompletion').val( defaults['customer_id_autocompletion'] )
      @userInfo( user_id: defaults['customer_id'] )

    # show template UI
    new App.TemplateUI(
      el:          @el.find('#ticket_template'),
      template_id: template['id'],
    )

    # show text module UI
    new App.TextModuleUI(
      el: @el.find('#text_module'),
    )

  localUserInfo: (params) =>
    @userInfo( user_id: params.customer_id )

  articleTypeSet: (name) =>
    console.log 'SET', name
    @el.find('.article-type').removeClass('active')
    @el.find('.article-type[data-type="' + name + '"]').addClass('active')
    @el.find('[name="article_type"]').val(name)

  articleTypeSelect: (e) =>
    console.log 'SELECT', e
    e.preventDefault()
    article_type = $(e.target).parent().data('type')
    if !article_type
      article_type = $(e.target).data('type')
    @articleTypeSet( article_type )
    @article_type = article_type

  userNew: (e) =>
    e.preventDefault()
    new UserNew()

  cancel: ->
    @navigate '#'

  submit: (e) ->
    e.preventDefault()

    # get params
    params = @formParam(e.target)

    # fillup params
    if !params.title
      params.title = params.subject

    # create ticket
    object = new App.Ticket
    @log 'updateAttributes', params, @article_type, @article_type_map[@article_type]

    # find sender_id
    sender = App.Collection.findByAttribute( 'TicketArticleSender', 'name', @article_type_map[@article_type] )
    type   = App.Collection.findByAttribute( 'TicketArticleType', 'name', @article_type )
    if params.group_id
      group  = App.Collection.find( 'Group', params.group_id )

    # create article
    if sender.name is 'Customer'
      params['article'] = {
        to:                       (group && group.name) || ''
        from:                     params.customer_id_autocompletion
        subject:                  params.subject
        body:                     params.body
        ticket_article_type_id:   type.id
        ticket_article_sender_id: sender.id
        form_id:                  @form_id
      }
    else
      params['article'] = {
        from:                     (group && group.name) || ''
        to:                       params.customer_id_autocompletion
        subject:                  params.subject
        body:                     params.body
        ticket_article_type_id:   type.id
        ticket_article_sender_id: sender.id
        form_id:                  @form_id
      }

    object.load(params)

    # validate form
    errors = object.validate()

    # show errors in form
    if errors
      @log 'error new', errors
      @formValidate( form: e.target, errors: errors )

    # save ticket, create article
    else

      # disable form
      @formDisable(e)
      ui = @
      object.save(
        success: ->

          # notify UI
          ui.notify
            type:    'success',
            msg:     App.i18n.translateContent( 'Ticket %s created!', @number ),
            link:    "#ticket/zoom/#{@id}"
            timeout: 12000,

          # create new create screen
          ui.render()

          # scroll to top
          ui.scrollTo()

        error: ->
          ui.log 'save failed!'
          ui.formEnable(e)
      )


class UserNew extends App.ControllerModal
  constructor: ->
    super
    @render()

  render: ->

    @html App.view('agent_user_create')( head: 'New User' )

    new App.ControllerForm(
      el: @el.find('#form-user'),
      model: App.User,
      required: 'quick',
      autofocus: true,
    )

    @modalShow()

  submit: (e) ->
    @log 'submit'
    e.preventDefault()
    params = @formParam(e.target)

    # if no login is given, use emails as fallback
    if !params.login && params.email
      params.login = params.email

    user = new App.User

    # find role_id
    role = App.Collection.findByAttribute( 'Role', 'name', 'Customer' )
    params.role_ids = role.id
    @log 'updateAttributes', params
    user.load(params)

    errors = user.validate()
    if errors
      @log 'error new', errors
      @formValidate( form: e.target, errors: errors )
      return

    # save user
    ui = @
    user.save(
      success: ->

        # force to reload object
        callbackReload = (user) ->
          realname = user.displayName()
          $('#create_customer_id').val( user.id )
          $('#create_customer_id_autocompletion').val( realname )

          # start customer info controller
          ui.userInfo( user_id: user.id )
          ui.modalHide()
        App.Collection.find( 'User', @id, callbackReload , true )

      error: ->
        ui.modalHide()
    )

App.Config.set( 'ticket_create', Index, 'Routes' )
App.Config.set( 'ticket_create/:ticket_id/:article_id', Index, 'Routes' )

App.Config.set( 'TicketNew', { prio: 8000, parent: '', name: 'New', target: '#ticket_create', role: ['Agent'] }, 'NavBarRight' )

