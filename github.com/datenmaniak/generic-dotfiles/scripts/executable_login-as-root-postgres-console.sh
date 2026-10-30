
# ❯ cat login-postgres.sh 
#psql -h 192.168.1.2 -p 5432 -U postgres -W 

kubectl exec -it deployment/postgres -n postgres -- psql -U postgres -W
