    throttles = {}

    module.exports = (name,duration,cb) ->
      if throttles[name]
        clearTimeout throttles[name]
      throttles[name] = setTimeout cb, duration
