import './enum/acl.dart';

String aclToString(ACL acl) {
  switch (acl) {
    case ACL.private:
      return 'private';
    case ACL.public_read:
      return 'public-read';
    case ACL.public_read_write:
      return 'public-read-write';
    case ACL.aws_exec_read:
      return 'aws-exec-read';
    case ACL.authenticated_read:
      return 'authenticated-read';
    case ACL.bucket_owner_read:
      return 'bucket-owner-read';
    case ACL.bucket_owner_full_control:
      return 'bucket-owner-full-control';
    case ACL.log_delivery_write:
      return 'log-delivery-write';
  }
}
