#= require bootstrap/modal

((E, G, $) ->

  $(document).ajaxSend (e, xhr, options) ->
    token = $('meta[name=\'csrf-token\']').attr('content')
    xhr.setRequestHeader 'X-CSRF-Token', token
    return


  class golumn
    constructor: (id) ->
      @id = id

      @selectedItemsIndex = {}

      @moveAnimalsModal =
        show: ko.observable false
        container: ko.observable new G.Container(undefined, undefined, [], undefined)
        animals: ko.observableArray []
        started_at: ko.observable ''
        stopped_at: ko.observable ''
        worker: ko.observable
          id: ko.observable undefined
          name: undefined
        variant: ko.observable
          id: ko.observable undefined
          name: undefined
        group: ko.observable undefined
        alert: ko.observableArray []
        animals_ids: ko.pureComputed () =>
          ko.utils.arrayMap @moveAnimalsModal.animals(), (a) =>
            a.id
          .join(',')


      @animal_moving_url = ''

      @showAnimalDetailsModal = ko.observable false
      @showNewGroupModal = ko.observable false

      @animalDetailsModalOptions = ko.observable false

      @newGroupModalOptions =
        group: ko.observable ''
        variantId: ko.observable ''


      @cancelAnimalDetails = () =>
        @animalDetailsModalOptions false
        @showAnimalDetailsModal false

      @cancelNewGroup = () =>
        @showNewGroupModal false

      @groups = ko.observableArray []
      @containers = ko.observableArray []
      @animals = ko.observableArray []


      @drop = ko.observable
      @hoverdrop = ko.observable

      @enableDropZones = (state = false) =>
        ko.utils.arrayForEach @groups(), (group) =>
          group.droppable state
          ko.utils.arrayForEach group.containers(), (container) =>
            container.droppable state unless container.protect

      @toggleAnimalDetailsModal = (animal) =>
        @animalDetailsModalOptions animal
        @showAnimalDetailsModal true
        return

      @toggleNewGroupModal = () =>
        @showNewGroupModal true
        return

      @toggleMoveAnimalModal = (container, group) =>

        @moveAnimalsModal.group(group) unless group is undefined
        @moveAnimalsModal.container(container) unless container is undefined

        @moveAnimalsModal.started_at(new Date().toISOString())
        @moveAnimalsModal.stopped_at(new Date().toISOString())


        for id, item of @selectedItemsIndex
          @moveAnimalsModal.animals.push item

        E.dialog.open @animal_moving_url,
          returns:
            success: (frame, data, status, request) ->
              frame.dialog "close"
              return

            invalid: (frame, data, status, request) ->
              frame.html request.responseText
              return


#        @moveAnimalsModal.show(true)


      @impactSelectedItems = =>
        count = Object.keys(@selectedItemsIndex).length
        $el = $('.interventions-accessor').find('[data-toggle=dropdown]')

        unless $el.data('name')
          $el.data('name', $el.html())

        # TODO: set icon or text to explain counting.
        $el.html("#{$el.data('name')} (#{count})")

        @animal_moving_url = $('a[data-intervention-accessor=animal_group_changing]').attr('href')
        parameters = $.param
            animals_ids: Object.keys(app.selectedItemsIndex)

        @animal_moving_url += "&#{parameters}"


      @moveAnimals = () =>

        #if its a new container
        if @moveAnimalsModal.container().parent is undefined

          @moveAnimalsModal.container().parent = @moveAnimalsModal.group()
          @moveAnimalsModal.group().containers.push @moveAnimalsModal.container()

        $("[data-move-animals-updater]")

        .on 'ajax:success', (data, status, xhr) =>
          ko.utils.arrayForEach @moveAnimalsModal.animals(), (animal) =>
            @moveAnimalsModal.show false

            oldContainer = animal.parent

            newContainer = @moveAnimalsModal.container()
            animal.parent = newContainer
            animal.checked false
            newContainer.items.push animal

            oldContainer.items.remove(animal)

            @resetMoveAnimalsModal()


        .on 'ajax:error', (xhr, status, error) =>
          @moveAnimalsModal.alert status.responseJSON.errors


      @resetMoveAnimalsModal = () =>

        @moveAnimalsModal.show false
        @moveAnimalsModal.container new G.Container(undefined, undefined, [], undefined)
        @moveAnimalsModal.animals.removeAll()
        @moveAnimalsModal.started_at ''
        @moveAnimalsModal.stopped_at ''
        @moveAnimalsModal.variant().id undefined
        @moveAnimalsModal.variant().name = undefined
        @moveAnimalsModal.worker().id undefined
        @moveAnimalsModal.worker().name = undefined
        @moveAnimalsModal.group undefined
        @moveAnimalsModal.alert []


      @resetSelectedItems = () =>
        for id, item  of @selectedItemsIndex
          item.checked(false)

        @selectedItemsIndex = {}


      @showAddGroup = (item) =>
        return item() == @groups().length-1

      @addGroup = () =>
        if group = @newGroupModalOptions.group

          $.ajax '/backend/animals/add_group',
            type: 'PUT',
#            type: 'GET',
            dataType: 'JSON',
            data: {name:group(),variant_id: @newGroupModalOptions.variantId()},
            success: (res) =>
              if res.id
                @groups.push new golumn.Group(res.id, res.name)

              @showNewGroupModal false
              return true

            error: (res) =>
              @showNewGroupModal false
              return false


  @loadData = (golumn, element) =>
    $.ajax '/backend/animals/load_animals',
      type: 'GET'
      dataType: 'JSON'
      data:
        golumn_id: golumn
      beforeSend: () ->
        element.addClass("loading")
        return
      complete: () ->
        element.removeClass("loading")
        return
      success: (json_data) ->
        groups = ko.utils.arrayMap json_data, (jGroup) =>

          group = new G.Group(jGroup.id, jGroup.name, [])

          places = ko.utils.arrayMap jGroup.places, (jPlace) =>

            container = new G.Container(jPlace.id, jPlace.name, [], group)

            animals = ko.utils.arrayMap jPlace.animals, (animal) =>
              new G.Item(animal.id, animal.name, animal.picture_path, animal.status, animal.sex_text, animal.identification_number, container)

            container.items animals
            container

          group.containers places

        window.app.groups = ko.observableArray(groups)

        ko.applyBindings window.app

        return true

      error: (data) ->
        return false

    return

  $(document).on 'click', 'a[data-intervention-accessor]', (e) =>
    unless app.selectedItemsIndex is undefined
      link = e.currentTarget.getAttribute('href')
      # assume link already has parameters (at least procedure name ?)
      link += "&#{$.param({
        animals_ids: Object.keys(app.selectedItemsIndex)
      })}"

    E.dialog.open link,
      returns:
        success: (frame, data, status, request) ->
          frame.dialog "close"
          return

        invalid: (frame, data, status, request) ->
          frame.html request.responseText
          return
    false


  $(document).ready ->
    # $("*[data-golumns]").mousewheel (event, delta) ->
    #   if $(this).prop("wheelable") != "false"
    #     @scrollLeft -= (delta * 30)
    #     event.preventDefault()


    $("*[data-golumns='animal']").each ->
      golumn_id = $(this).data("golumns")
      window.app = new golumn(golumn_id)
      window.loadData(golumn_id, $(this))

) ekylibre, golumn, jQuery
