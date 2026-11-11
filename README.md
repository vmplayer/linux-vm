# VM Linux com navegador

VM Ubuntu com interface XFCE e Firefox, acelerada por KVM, internet via NAT e
acesso gráfico pelo navegador usando noVNC.

## Criar e iniciar

```bash
chmod +x vm/*.sh
./vm/start-vm.sh
```

Abra `http://localhost:6080/vm.html?cache=2`. Na primeira execução, aguarde a
instalação do XFCE e do Firefox terminar dentro da VM; isso pode levar alguns
minutos. O usuário padrão é `vmuser` e a senha é `vmuser`.

Se a tela mostrar apenas o terminal Ubuntu após uma tentativa anterior, recrie
o disco da VM para aplicar a instalação gráfica atualizada:

```bash
./vm/stop-vm.sh --purge
./vm/start-vm.sh
```

O launcher usa 6 GiB de RAM e todos os 2 vCPUs disponíveis neste ambiente.
Dentro da VM, a internet sai pela rede NAT do QEMU. O SSH da VM, quando
necessário, fica disponível em `localhost:10022`.

## Parar e remover

```bash
./vm/stop-vm.sh
```

Para apagar também o disco da VM e começar de novo:

```bash
./vm/stop-vm.sh --purge
```

## Observações

- É necessário ter `/dev/kvm` disponível para o melhor desempenho.
- O primeiro boot baixa a imagem Ubuntu e pacotes da VM.
- O acesso noVNC deve ficar restrito ao ambiente local; não exponha a porta
	`6080` publicamente sem autenticação ou túnel seguro.
