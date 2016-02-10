# Scenario for OpenStack Liberty 

This is a scenario for the [xp5k-openstack](https://github.com/pmorillon/xp5k-openstack) deployment script. [Pascal](https://twitter.com/pmorillon)'s script allows to deploy OpenStack on [Grid'5000](http://grid5000.fr/) thanks to scenarios. The scenarios define the version of OpenStack but also the whole configuration. Thus we have a full control on how will be our installation. 

My scenario deploys the [Liberty version](https://www.openstack.org/software/liberty/) of OpenStack. It has the particularity to deploy many _compute_ nodes and uses 1 network interface. It means that the OpenStack system messages and the VMs network communication are shared into the same network interface. The reason of this choice is because some Grid'5000 site/cluster do not allow to have more than 1 network interface. If you prefer to use 2 network interafaces in order to separate these 2 network channels, go take a look at the [xp5k-openstack/scenarios/liberty_multinodes](https://github.com/msimonin/xp5k-openstack/tree/multinode/scenarios/liberty_multinodes) scenario (by [Matthieu](https://twitter.com/SimoninMatthieu)). 

## How to

First, create a file in the folder _xp5k-openstack_ with the following content:

    scenario      'liberty_multinodes_singleinterface'

    jobname       '<funnyJobName>'
    site          '<siteName>'
    cluster       '<clusterName>'
    walltime      '1:00:00'
    computes      1

    public_key    "/home/<username>/.ssh/id_rsa.pub"
    gateway       "#{ENV['USER']}@frontend.#{self[:site]}.grid5000.fr"

Edit the content to correspond to your need. 

Now you can execute the following command to start the deployment. It takes about 25 minutes to execute. 

    $ rake run
