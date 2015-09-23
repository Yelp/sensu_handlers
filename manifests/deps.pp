define sensu_handlers::deps ($dependencies) {
  if $dependencies {
    create_resources(
      'package',
      $dependencies,
      {before => Sensu::Handler[$title]}
    )
  }
}
