#!/usr/bin/env python3
"""Generate target-scoped Shodan recon queries without making network requests."""

import argparse


def quoted(value: str) -> str:
    return '"' + value.replace('"', '\\"') + '"'


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("domain", help="In-scope root domain, e.g. target.com")
    parser.add_argument("--org", help="Organization name as indexed by Shodan")
    parser.add_argument("--asn", help="ASN with or without AS prefix")
    parser.add_argument("--net", dest="netblock", help="Owned CIDR netblock")
    args = parser.parse_args()

    domain = args.domain.removeprefix("https://").removeprefix("http://").strip("/")
    bases = [
        f"hostname:{quoted(domain)}",
        f"ssl.cert.subject.cn:{quoted(domain)}",
        f"ssl:{quoted(domain)}",
        f"ssl:{quoted(domain)} -hostname:{quoted(domain)}",
    ]
    if args.org:
        bases.append(f"org:{quoted(args.org)}")
    if args.asn:
        asn = args.asn.upper()
        bases.append(f"asn:{asn if asn.startswith('AS') else 'AS' + asn}")
    if args.netblock:
        bases.append(f"net:{args.netblock}")

    suffixes = [
        "http.status:200",
        "port:8080",
        'port:9200 "X-elastic-product"',
        'port:5601 "kbn-name"',
        'product:"Jenkins"',
        'http.title:"Grafana"',
        'http.title:"phpMyAdmin"',
        '"WWW-Authenticate"',
        '"access-control-allow-origin"',
    ]

    print("# Attribution")
    print("\n".join(bases))
    print("\n# Targeted combinations")
    for base in bases:
        for suffix in suffixes:
            print(f"{base} {suffix}")


if __name__ == "__main__":
    main()
