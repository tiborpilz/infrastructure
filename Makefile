all: main.tf.json cluster.yml

secrets/ssh_key secrets/ssh_key.pub:
	ssh-keygen -b 2048 -t rsa -f ./secrets/ssh_key -q -N ""

main.tf.json: terraform.jsonnet secrets/ssh_key secrets/ssh_key.pub
	jsonnet terraform.jsonnet -o main.tf.json

cluster.yml: rke.jsonnet secrets/ssh_key secrets/ssh_key.pub
	jsonnet rke.jsonnet -o cluster.yml

clean:
	rm main.tf.json cluster.yml secrets/ssh_key secrets/ssh_key.pub
