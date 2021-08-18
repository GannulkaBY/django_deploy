### Description

Repository contains script to deploy Django image to the remote host and docker-compose to run the application.

### Database
MySQL. 
Connection is set in web_django/settings.py

### Super user
If Django deployed at first time, scripts apply migration to database and creates a super user with default login and password

```python
User.objects.create_superuser('admin', 'admin@myproject.com', 'password')

```
### Run

Application is run by docker stack deploy. It runs 3 services
```bash
ID                  NAME                   MODE                REPLICAS            IMAGE                PORTS
mz9vptgjsx0v        django_db              replicated          1/1                 mysql:5.7            
2g849f1ewav7        django_reverse-proxy   replicated          1/1                 gannagp/reverse:30   *:80->80/tcp
vc9ipvowy1bm        django_web             replicated          1/1                 gannagp/django:30    *:8080->8080/tcp
```

to check the application - http://yourhost/admin/auth/user