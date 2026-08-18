Gem::Specification.new do |spec|
  spec.name = "anti-slop-ror"
  spec.version = "0.1.0"
  spec.summary = "Focused, no-autocorrect Rails safety cops"
  spec.authors = ["Anti Slop contributors"]
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.files = Dir["lib/**/*", "config/**/*", "LICENSE", "README.md"]
  spec.add_dependency "lint_roller", ">= 1.1"
  spec.add_dependency "rubocop", ">= 1.72"
end
