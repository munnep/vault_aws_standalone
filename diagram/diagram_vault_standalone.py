from diagrams import Cluster, Diagram, Edge
from diagrams.aws.compute import EC2
from diagrams.aws.network import VPC, PrivateSubnet, PublicSubnet, InternetGateway, NATGateway, ElbApplicationLoadBalancer
from diagrams.onprem.client import User


# Variables
title = "VPC with 1 public subnet for the Vault server"
outformat = "png"
filename = "diagram_vault_standalone"
direction = "TB"


with Diagram(
    name=title,
    direction=direction,
    filename=filename,
    outformat=outformat,
) as diag:
    # Non Clustered
    user = User("user")

    # Cluster 
    with Cluster("aws"):
        with Cluster("vpc"):
            igw_gateway = InternetGateway("igw")
    
                            
            with Cluster("Availability Zone: eu-north-1a \n\n  "):
                # Subcluster 
                with Cluster("subnet_public1"):
                     ec2_vault_server = EC2("Vault_server")

    # Diagram

    user >> ec2_vault_server
     

diag
