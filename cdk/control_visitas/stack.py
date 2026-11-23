"""Pila del control: una instancia EC2 que construye la imagen de app/ y la ejecuta con Docker.

La base de datos Aurora NO está en esta pila: es del profesor y está en otra cuenta. La pila
solo necesita saber su endpoint (db_host) y el nombre del secreto con las credenciales.
"""

import aws_cdk as cdk
from aws_cdk import aws_ec2 as ec2
from aws_cdk import aws_iam as iam
from constructs import Construct

# Imagen de Ubuntu 24.04 que Canonical mantiene actualizada en un parámetro público de SSM
UBUNTU_SSM = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"


class ControlVisitasStack(cdk.Stack):
    def __init__(self, scope: Construct, construct_id: str, *, exam_id: str, mi_ip: str, repo_url: str,
                 commit: str, db_host: str, db_name: str, secret_name: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # El laboratorio ya tiene una VPC por defecto; la pila no la crea
        vpc = ec2.Vpc.from_lookup(self, "Vpc", is_default=True)

        # Grupo de seguridad de la instancia. La salida está abierta (por defecto), así que la
        # instancia puede llegar a Aurora por el 5432.
        sg = ec2.SecurityGroup(self, "AppSg", vpc=vpc, description="Control visitas: HTTP y SSH")
        # TODO (Tarea 2): permite la entrada HTTP (puerto 80) desde cualquier dirección IPv4.

        # SSH solo desde tu IP (la escribe params.sh en cdk.json)
        if mi_ip:
            sg.add_ingress_rule(ec2.Peer.ipv4(f"{mi_ip}/32"), ec2.Port.tcp(22), "SSH desde mi IP")

        # User data: instala Docker, clona tu fork en el commit desplegado, construye la imagen y
        # arranca el contenedor.
        user_data = ec2.UserData.for_linux()
        user_data.add_commands(
            "set -eux",
            # security.ubuntu.com está fuera de AWS y puede tardar minutos. El espejo de Ubuntu de la
            # región también tiene las actualizaciones de seguridad y responde en segundos.
            "sed -i 's#http://security.ubuntu.com/ubuntu#http://us-east-1.ec2.archive.ubuntu.com/ubuntu#g'"
            " /etc/apt/sources.list.d/ubuntu.sources",
            "apt-get update",
            "apt-get install -y docker.io git",
            f"git clone {repo_url} /opt/control-visitas",
            f"git -C /opt/control-visitas checkout {commit}",
            f"docker build --build-arg GIT_COMMIT={commit} -t control-visitas /opt/control-visitas/app",
            " ".join([
                "docker run -d --name contenedor-control-visitas --restart unless-stopped",
                # TODO (Tarea 2): publica el puerto 80 de la instancia en el puerto del contenedor.
                f"-e EXAM_ID={exam_id}",
                f"-e DB_HOST={db_host}",
                f"-e DB_NAME={db_name}",
                # TODO (Tarea 3): pasa al contenedor el nombre del secreto (variable secret_name).
                "-e AWS_REGION=us-east-1",
                "control-visitas",                  # la imagen construida con docker build -t
            ]),
        )

        instance = ec2.Instance(
            self, "App", vpc=vpc,
            instance_name=f"control-visitas-{exam_id}",
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PUBLIC),
            # 2 GB de memoria: la instancia compila la aplicación con Maven dentro de docker build
            instance_type=ec2.InstanceType("t3.small"),
            machine_image=ec2.MachineImage.from_ssm_parameter(UBUNTU_SSM),
            security_group=sg,
            # Par de claves del laboratorio, para entrar por SSH si hace falta depurar
            key_pair=ec2.KeyPair.from_key_pair_name(self, "VocKey", "vockey"),
            # El L2 Instance crea por defecto un rol IAM, que el laboratorio no permite. Se reutiliza
            # LabInstanceProfile, importado junto con su rol (si solo se da el nombre del perfil, el
            # L2 sigue creando un rol propio).
            instance_profile=iam.InstanceProfile.from_instance_profile_attributes(
                self, "LabInstanceProfile",
                instance_profile_arn=f"arn:aws:iam::{self.account}:instance-profile/LabInstanceProfile",
                role=iam.Role.from_role_arn(self, "LabRole", f"arn:aws:iam::{self.account}:role/LabRole"),
            ),
            # El contenedor está un salto de red más allá de la instancia (la red bridge de Docker).
            # Con el límite por defecto (1), la respuesta del servicio de metadatos no le llegaría y
            # la aplicación no encontraría las credenciales de LabRole.
            http_put_response_hop_limit=2,
            user_data=user_data,
            user_data_causes_replacement=True,
        )

        # IP pública de la instancia
        eip = ec2.CfnEIP(self, "Eip", domain="vpc", instance_id=instance.instance_id,
                         tags=[cdk.CfnTag(key="Name", value=f"control-visitas-{exam_id}")])

        cdk.CfnOutput(self, "PublicIp", value=eip.attr_public_ip)
        cdk.CfnOutput(self, "Url", value=f"http://{eip.attr_public_ip}/")
        cdk.CfnOutput(self, "Commit", value=commit)
