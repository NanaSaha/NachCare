module Domain
  module Enrollment
    # 8-char activation codes from an alphabet with the visually-confusable
    # characters removed (no 0/O, 1/I/L) per Section 8 M1 ("8 chars,
    # unambiguous alphabet") — the code gets read off a printed A5 sheet and
    # typed on a phone, so ambiguity there is a real activation-failure mode.
    class CodeGenerator
      ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".freeze
      LENGTH = 8

      def self.call
        Array.new(LENGTH) { ALPHABET[SecureRandom.random_number(ALPHABET.length)] }.join
      end
    end
  end
end
