
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "red_celery/version"

Gem::Specification.new do |spec|
  spec.name          = "red_celery"
  spec.version       = RedCelery::VERSION
  spec.authors       = ["Alex Emelyanov"]
  spec.email         = ["holyketzer@gmail.com"]

  spec.summary       = %q{Ruby Celery client}
  spec.description   = %q{Support v2 protocol see http://docs.celeryproject.org/en/latest/internals/protocol.html}
  spec.homepage      = "https://github.com/deeplearninc/redcelery"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/deeplearninc/red_celery"
    # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "bunny" , "~> 2.14"
  spec.add_dependency "msgpack", "~> 1.3"

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "concurrent-ruby", "~> 1.1"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "ruby-prof"
end
