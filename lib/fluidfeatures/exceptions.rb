
class FFeaturesException < Exception
end

class FFeaturesConfigInvalid < FFeaturesException
end

class FFeaturesConfigFileNotExists < FFeaturesConfigInvalid
end

class FFeaturesBadParam < FFeaturesException
end

class FFeaturesAppStateLoadFailure < FFeaturesException
end

