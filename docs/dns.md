# DNS Basics (and Why "It's Always DNS")

DNS turns names into answers, usually IP addresses. Nearly every network call starts with a DNS lookup. When the lookup is wrong, slow, or cached, the failure shows up as something else: a timeout, "connection refused", a TLS certificate error, or a service that works on one machine but not another. That's the joke: DNS failures rarely look like DNS failures.

## Record types

| Type | Maps | Example | Notes |
|---|---|---|---|
| `A` | name → IPv4 | `app.example.com → 20.1.2.3` | The common case |
| `AAAA` | name → IPv6 | `app.example.com → 2603:1030::1` | |
| `CNAME` | name → another name | `www.example.com → app.azurewebsites.net` | Resolver then looks up the target. Can't coexist with other records on the same name, so not allowed at the zone apex (`example.com`) |
| `ALIAS` / alias record | apex → cloud resource | `example.com → my-alb` | Provider feature (Route 53 Alias, Azure alias record) that works around the apex CNAME restriction |
| `MX` | domain → mail servers | `example.com → 10 mail.example.com` | Number is priority; lower wins |
| `TXT` | name → free text | `"v=spf1 ..."`, domain verification tokens | Used for SPF/DKIM/DMARC and proving ownership (e.g. Azure custom domains, ACM/Let's Encrypt validation) |
| `NS` | zone → its authoritative servers | `example.com → ns1-01.azure-dns.com` | Delegation: how the parent zone points to the servers that hold the records |
| `SOA` | zone metadata | primary server, serial, timers | One per zone. Its last field sets how long *negative* answers are cached |
| `PTR` | IP → name (reverse) | `3.2.1.20.in-addr.arpa → app.example.com` | Used by mail servers, logging, some auth checks |
| `SRV` | service → host + port | `_ldap._tcp.example.com → 0 0 389 dc1.example.com` | Used by AD, SIP, some service discovery |
| `CAA` | domain → allowed CAs | `0 issue "letsencrypt.org"` | Which certificate authorities may issue certs |

Every record has a **TTL** (time to live, in seconds), which says how long resolvers may cache it.

## The players

- **Stub resolver:** the small DNS client in the OS (glibc, `systemd-resolved`, Windows DNS Client). It doesn't resolve anything itself. It asks a configured server and waits for the answer.
- **Recursive resolver:** the server the stub asks. It does the actual work: walks the hierarchy, caches results, returns the final answer. Examples: your ISP's resolver, `8.8.8.8`, `1.1.1.1`, Azure's `168.63.129.16`, AWS's VPC resolver.
- **Authoritative server:** holds the actual records for a zone and gives the definitive answer. Example: Azure DNS / Route 53 name servers for `example.com`.

## How a server knows which DNS server to use

On Linux, in order:

1. **`/etc/nsswitch.conf`** decides the lookup order, typically `hosts: files dns`: check `/etc/hosts` first, then DNS.
2. **`/etc/hosts`** holds static overrides. A forgotten entry here beats DNS every time and is a classic gotcha.
3. **`/etc/resolv.conf`** lists the DNS servers to use:
   ```
   nameserver 127.0.0.53        # systemd-resolved local stub (forwards to the real servers)
   search internal.cloudapp.net # appended to short names
   options ndots:1 timeout:2
   ```
   With `systemd-resolved`, run `resolvectl status` to see the real upstream servers.
4. **Where those settings come from:** almost always **DHCP**. In the cloud, the VNet/VPC's DHCP hands out the DNS server address. That's why "change the VNet's DNS servers" doesn't take effect until the VM renews its lease or reboots.

Other runtimes add their own layers. Containers get a generated `resolv.conf`, Kubernetes points pods at CoreDNS, and the JVM keeps its own DNS cache.

## What actually goes over the wire

A lookup for `app.example.com` with nothing cached:

```
VM (stub)                  Recursive resolver                  Authoritative servers
   │  "A app.example.com?"         │
   │ ─────────────────────────────►│
   │   UDP 53                      │  "who handles .com?" ─────────► root server
   │                               │  ◄────── NS for .com
   │                               │  "who handles example.com?" ──► .com server
   │                               │  ◄────── NS for example.com
   │                               │  "A app.example.com?" ────────► example.com's NS
   │                               │  ◄────── 20.1.2.3, TTL 300
   │  ◄─────────────────────────── │  (caches it for 300s)
   │  20.1.2.3                     │
```

- **Stub to recursive** is a *recursive* query: "give me the final answer". **Recursive to authoritative** is a chain of *iterative* queries: each server points to the next one down.
- **Transport:** UDP port 53 by default. If the response is too large (big TXT records, DNSSEC), the server sets the **TC (truncated)** flag and the client retries over **TCP 53**. Firewalls that only allow UDP 53 break those large responses.
- **Each query has an ID.** The client matches the response by ID and source port. Responses are small: one packet each way.
- **Encrypted DNS:** DNS-over-TLS (TCP 853) and DNS-over-HTTPS (443) exist, but inside cloud networks plain UDP/TCP 53 is the norm.
- **Caching happens at every layer:** the app, the OS stub, the recursive resolver. Each one honors the TTL, but some ignore it, like the JVM or certain clients.
- **Negative answers are cached too.** `NXDOMAIN` (name doesn't exist) is cached for the time set by the zone's SOA. If you query a name *before* creating the record, you can keep getting "doesn't exist" for minutes after you create it.

## Common issues in Azure

- **The magic IP `168.63.129.16`.** Azure's built-in resolver. It resolves public names, Private DNS zones linked to the VNet, and VM hostnames. It only answers traffic coming from inside Azure, so on-premises machines can't use it directly.
- **Private endpoints resolving to public IPs.** The single most common Azure DNS problem.
  - With a private endpoint, `mystorage.blob.core.windows.net` CNAMEs to `mystorage.privatelink.blob.core.windows.net`.
  - That name resolves to the private IP *only if* a Private DNS zone `privatelink.blob.core.windows.net` exists and is **linked to the VNet** the query comes from.
  - Missing zone, missing link, or a client using a different resolver: you get the public IP, and the connection is blocked or leaves the network.
- **Custom DNS servers on the VNet.** If you set the VNet to use your own DNS servers (e.g. domain controllers), those servers must forward Azure names to `168.63.129.16`. Otherwise private zones and private endpoints stop resolving. Existing VMs also need a reboot or DHCP renewal to pick up the change.
- **Hybrid (on-prem ↔ Azure).** On-prem can't reach `168.63.129.16`.
  - Use **Azure DNS Private Resolver**: an inbound endpoint receives on-prem queries, and an outbound endpoint with forwarding rules sends Azure queries to on-prem DNS.
  - On-prem DNS needs **conditional forwarders** for `privatelink.*` zones pointing at the inbound endpoint.
- **App Service VNet integration** (relevant to this repo). Outbound calls from the app use the VNet's DNS settings, so they hit the same private endpoint and Private DNS zone issues as VMs.
- **Custom domains on App Service** need a `CNAME` (or an `A` record plus an `asuid` `TXT` verification record) before the hostname binding succeeds.

## Common issues in AWS

- **The VPC resolver** ("Route 53 Resolver" / "AmazonProvidedDNS") lives at the **VPC CIDR base + 2** (e.g. `10.0.0.2`) and at `169.254.169.253`.
- **VPC DNS attributes.** `enableDnsSupport` must be on for the resolver to work at all. `enableDnsHostnames` must be on for instances to get DNS names and for private hosted zones to work properly. Both are easy to leave off in a hand-built VPC.
- **Private hosted zones** only resolve in VPCs **associated** with them. This is the AWS equivalent of Azure's VNet link. Cross-account association needs an extra authorization step.
- **Interface VPC endpoints:** with "private DNS" enabled, `sqs.us-east-1.amazonaws.com` resolves to the endpoint's private IPs inside the VPC. Disabled, or in a VPC that isn't using the AWS resolver, it resolves to the public IP.
- **Hybrid** uses **Route 53 Resolver endpoints**: inbound for on-prem → AWS, outbound + forwarding rules for AWS → on-prem. Same pattern as Azure DNS Private Resolver.
- **Throttling.** The VPC resolver allows about **1024 packets per second per network interface**. Busy hosts and Kubernetes nodes hit this and see intermittent timeouts. The fix is caching (NodeLocal DNSCache, `nscd`) or fewer queries.
- **Apex records.** `example.com` can't be a CNAME to an ALB or CloudFront, so use a Route 53 **Alias** record.

## Issues you'll see on any platform

- **Stale caches after a change.** You update a record, but clients keep the old answer until the TTL expires. Lower the TTL (e.g. to 60s) *before* a migration, not during it.
- **Long-lived processes caching forever.** The JVM's DNS cache (`networkaddress.cache.ttl`), connection pools, and clients that resolve once at startup keep using an old IP after a failover.
- **Kubernetes `ndots:5`.** Pods default to `ndots:5`, so a lookup for `api.example.com` (2 dots) first tries every search domain (`api.example.com.default.svc.cluster.local`, ...) before the real name. That means 4–5 failed queries per lookup, which adds latency and load. Fix it with a trailing dot (`api.example.com.`) or a lower `ndots`.
- **Split-horizon surprises.** The same name returns a private IP inside the network and a public IP outside. Things work from a VM but not from your laptop, or the reverse.
- **Blocked TCP 53.** Small answers work over UDP, large ones fail. This looks intermittent.
- **`/etc/hosts` overrides** someone added for testing and forgot to remove.
- **Delegation mistakes.** You create a zone in Azure DNS/Route 53 but the registrar still lists the old name servers, so your records are never queried.

## Troubleshooting toolkit

```sh
dig app.example.com                   # ask the system's configured resolver
dig @168.63.129.16 app.example.com    # ask a specific resolver (compare answers)
dig +short app.example.com            # just the answer
dig +trace app.example.com            # walk root → TLD → authoritative yourself
dig app.example.com +tcp              # force TCP (tests blocked TCP 53)
dig -x 20.1.2.3                       # reverse lookup (PTR)
nslookup app.example.com              # available everywhere, including Windows
resolvectl status                     # which servers systemd-resolved actually uses
resolvectl query app.example.com      # resolve through systemd-resolved
getent hosts app.example.com          # resolve the way apps do (honors /etc/hosts + nsswitch)
cat /etc/resolv.conf /etc/hosts
```

**The key question when debugging:** *which resolver did this client ask, and what did it answer?* Run the lookup **from the failing machine**, not your laptop. Compare `getent` (what the app sees) with `dig` (what DNS says); if they differ, the cause is `/etc/hosts` or a local cache. If you get the public IP when you expected a private one, check the Private DNS zone link (Azure) or the hosted zone association (AWS).
