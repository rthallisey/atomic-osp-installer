===========================================================
Boot config for installing software-config agent for docker
============================================================

This directory has an environment file to declare a resource type
Heat::InstallConfigAgent.

This can be used by server user_data when booting a pristine image
to deploy a container with docker-compose hook , required to use
software deployment resources to deploy containers.

To deploy docker-compose hook in a container during boot, include the
following in the template:

  boot_config:
    type: Heat::InstallConfigAgent

  server:
    type: OS::Nova::Server
    properties:
      user_data_format: SOFTWARE_CONFIG
      user_data: {get_attr: [boot_config, config]}
      # ...

When creating the stack, reference the desired environment, eg:

  heat stack-create -e docker_agents_env.yaml \
       -f ../example-templates/example-pristine-atomic-docker-compose.yaml \
       deploy-to-pristine

To deploy with fedora atomic, upload fedora atomic qcow2 image to glance

 glance image-create --name fedora-atomic --disk-format qcow2 \
   --container-format bare --is-public True --file ./Fedora-Cloud-Atomic-20141203-21.x86_64.qcow2

=======================================================
Steps to build container image with docker-compose hook
=======================================================

Build docker image with the docker-compose hook

  $docker build -t xxxx/heat-docker-agents ../heat-docker-agents

Push the image to docker hub

  $docker push xxxx/heat-docker-agents