# verkle-block-explorer

A feature-poor ethereum block explorer dedicated to verkle trees. This isn't production software, it is meant as an example of how existing block explorers can upgrade their codebase to support verkle trees.

## Installation

 * Make sure that ruby, bundler and graphviz are available on your system. For example, on ubuntu:

```
> sudo apt update && sudo apt-get -y ruby bundler graphviz
```

 * Clone the repository and install the dependencies:

```
> git clone https://github.com/gballet/verkle-block-explorer
> cd verkle-block-explorer
> bundle install
> bundle exec rake db:migrate
```

 * Create the configuration file:

```
> cp config.yml.sample config.yml
> $EDITOR config.yml
```

 * Set the values of `network_name` and `rpc` to the name of your network, and that of your rpc endpoint, respectively.
 * Schedule the following command to be run every minute (e.g. in `cron`):

```
cd <path_to_the_cloned_repo> && bundle exec ./crawler.rb
```

## Running the block explorer

```
> bundle exec ./app.rb -o 0.0.0.0
```

The block explorer is now reachable at `http://localhost:4567`
