ambiente = "hom"
region   = "us-east-1"

# Classe minima disponivel no Learner Lab. Suficiente para a carga da fase.
instance_class    = "db.t3.micro"
allocated_storage = 20

# Alta disponibilidade exigida pela issue #61.
multi_az = true

# Backup automatico com uma semana de retencao.
backup_retention_period = 7
