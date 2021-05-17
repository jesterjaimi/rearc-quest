# rearc-quest-proxy

Herein contains the final submission of the rearc-quest assignment as requested by Cristina Orlando.

This repo contains the terraform ripcord script that fully automates the install of the rearc-quest into AWS, an nginx-proxy that allows http alb access to a load balanced cluster of quest servers being served by an auto-scaling group via a terraform declared launch template. TLS is also supported.

TLS connections to the quest ec2 instances require direct instance access. I tried to get the alb's to play nicely with my self signed certificates, but I couldn't get it to work. (health checks... bahhhhh!) But if my assumptions are correct, this is acceptable, because I would hope thatin 2021 AWS frowns on such questionable security configurations anyway.

The only change that needs to be made to ssh into the instances to thorughly inspect the configuration once running is to change the key_name in the launch configuration to an ssh key in your aws account and that you have access to the asssociated private key.

    "aws_launch_template" "quest_lt" {
        ...
        key_name = ${YOUR_KEY_NAME}
        ...
    }

I prefer to use tfswitch for local terraform environment version management...

    https://tfswitch.warrensbox.com/

If you want to reproduce what I did to make this fly, install tfswitch and then run...

    tfswitch

... choose v0.15.3 and you should be good to go.

To test this simply authenticate your local ./aws creds to your aws account, however you do this, move to the terraform directory, $(cd ./terraform) and run the following.

    terraform init
    terraform plan -out quest-plan
    terraform apply quest-plan

It will take a minute for everything to settle, but once you get the greenlight in the aws console, you can test as follows.

    http://$QUEST_ALB_PUBLIC_DNS
    https://$QUEST_EC2_INSTANCE

To tear down the infrastructure once your satisfied, run...

    terraform destroy

And that is all he wrote!
