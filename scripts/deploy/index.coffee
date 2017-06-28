## store the cwd
cwd = process.cwd()

path     = require("path")
_        = require("lodash")
os       = require("os")
chalk    = require("chalk")
Promise  = require("bluebird")
minimist = require("minimist")
la       = require("lazy-ass")
check    = require("check-more-types")

zip      = require("./zip")
ask      = require("./ask")
bump     = require("./bump")
meta     = require("./meta")
build    = require("./build")
upload   = require("./upload")
Base     = require("./base")
Linux    = require("./linux")
Darwin   = require("./darwin")

success = (str) ->
  console.log chalk.bgGreen(" " + chalk.black(str) + " ")

fail = (str) ->
  console.log chalk.bgRed(" " + chalk.black(str) + " ")

zippedFilename = (platform) ->
  # TODO use .tar.gz for linux archive. For now to preserve
  # same file format as before use .zip
  if platform == "linux" then "cypress.zip" else "cypress.zip"

# goes through the list of properties and asks relevant question
# resolves with all relevant options set
# if the property already exists, skips the question
askMissingOptions = (properties) -> (options = {}) ->
  questions = {
    platform: ask.whichPlatform,
    version: ask.deployNewVersion,
    # note: zip file might not be absolute
    zip: ask.whichZipFile
  }

  properties.reduce((prev, property) ->
    if (check.has(options, property)) then return prev
    question = questions[property]
    if (!check.fn(question)) then return prev
    la(check.fn(question), "cannot find question for property", property)
    prev.then(() ->
      question(options[property])
      .then((answer) ->
        options[property] = answer
        options
      )
    )
  , Promise.resolve(options))

## hack for @packages/server modifying cwd
process.chdir(cwd)

deploy = {
  meta:   meta
  Base:   Base
  Darwin: Darwin
  Linux:  Linux

  # getPlatform: (platform, options) ->
  #   platform ?= os.platform()
  #
  #   Platform = @[platform.slice(0, 1).toUpperCase() + platform.slice(1)]
  #
  #   throw new Error("Platform: '#{platform}' not found") if not Platform
  #
  #   options ?= @parseOptions(process.argv.slice(2))
  #
  #   (new Platform(platform, options))

  parseOptions: (argv) ->
    opts = minimist(argv)
    opts.runTests = false if opts["skip-tests"]
    opts

  bump: ->
    ask.whichBumpTask()
    .then (task) ->
      switch task
        when "run"
          bump.run()
        when "version"
          ask.whichVersion(meta.distDir)
          .then (v) ->
            bump.version(v)

  release: ->
    ## read off the argv
    options = @parseOptions(process.argv)

    release = (version) =>
      upload.s3Manifest(version)
      .then ->
        success("Release Complete")
      .catch (err) ->
        fail("Release Failed")
        reject(err)

    if v = options.version
      release(v)
    else
      ask.whichRelease(meta.distDir)
      .then(release)

  build: ->
    options = @parseOptions(process.argv)
    askMissingOptions(['version', 'platform'])(options)
    .then () ->
      build(options.platform, options.version)

  zip: ->
    # TODO only ask for built folder name
    options = @parseOptions(process.argv)
    askMissingOptions(['platform'])(options)
    .then (options) ->
      zipDir = meta.zipDir(options.platform)
      dest = path.resolve(zippedFilename(options.platform))
      zip.ditto(zipDir, dest)

  upload: ->
    console.log('#upload')
    options = @parseOptions(process.argv)
    askMissingOptions(['version', 'platform', 'zip'])(options)
    .then (options) ->
      la(check.unemptyString(options.zip),
        "missing zipped filename", options)
      options.zip = path.resolve(options.zip)
      options
    .then (options) ->
      console.log("Need to upload file %s", options.zip)
      console.log("for platform %s version %s",
        options.platform, options.version)

      upload.toS3({
        zipFile: options.zip,
        version: options.version,
        platform: options.platform
      })

  # goes through the entire pipeline:
  #   - build
  #   - zip
  #   - upload
  deploy: ->
    ## read off the argv
    # to skip further questions like platform and version
    # pass these as options like this
    #   npm run deploy -- --platform darwin --version 0.20.0
    options = @parseOptions(process.argv)
    askMissingOptions(['version', 'platform'])(options)
    .then(console.log)
    # .then (version) ->
    #   build(platform, version)
    # .then (built) =>
    #   console.log(built)
    #   src  = built.buildDir
    #   dest = path.resolve(zippedFilename(platform))
    #   zip.ditto(src, dest)
    # .then () ->
      # path.resolve("cypress.zip")
    # .then () =>
    #   la(check.unemptyString(options.zipFile),
    #     "missing zipped filename", options)
    #   console.log("Need to upload file %s", options.zipFile)
    #   console.log("for platform %s version %s",
    #     options.platform, options.version)
    #   upload.toS3({
    #     zipFile: options.zipFile,
    #     version: options.version,
    #     platform: options.platform
    #   })
}

module.exports = _.bindAll(deploy, _.functions(deploy))
