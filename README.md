# rearc-quest-proxy
This repo contains the nginx-proxy that allows http alb access to a load balanced cluster of quest servers being served by an auto-scaling group via a terraform declared launch template. tls connections to the quest ec2 instances require direct instance access. I tried to get the alb's to play nicely with my self signed certificates, but I couldn't get it to work, which if my assumptions are correct, is acceptable, because I would hope that AWS frowns on such questionable security configurations.

The only change that needs to be made to thorughly inspect the configuration once running is to change the key_name in the launch configuration to an ssh key in your aws account and that you have access to the private key.

    "aws_launch_template" "quest_lt" {
        ...
        key_name = ${YOUR_KEY_NAME}
        ...
    }

To test this simply authenticate your local ./aws creds to your aws account, however you do this, move to the terraform directory, $(cd ./terraform) and run the following.

    terraform plan -out quest-plan
    terraform apply quest-plan

It will take a minute for everything to settle, but once you get the greenlight in the aws console, you can test as follows.

    http://$QUEST_ALB_PUBLIC_DNS
    https://$QUEST_EC2_INSTANCE

To tear down the infrastructure once your satisfied, run...

    terraform destroy

And that is all he wrote!
