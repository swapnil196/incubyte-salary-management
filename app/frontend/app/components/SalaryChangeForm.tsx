import { Alert, Button, Group, Modal, NumberInput, Select, Stack, TextInput } from "@mantine/core"
import { useMutation, useQueryClient } from "@tanstack/react-query"
import { useState } from "react"
import { recordSalaryChange, type Reference } from "~/app/api/employees"
import { formatChangeReason } from "~/app/lib/format"

interface Props {
  employeeId: number
  opened: boolean
  onClose: () => void
  reference: Reference | undefined
  defaultCurrency: string
}

const today = () => new Date().toISOString().slice(0, 10)

export function SalaryChangeForm({ employeeId, opened, onClose, reference, defaultCurrency }: Props) {
  const queryClient = useQueryClient()
  const [amount, setAmount] = useState<string | number>("")
  const [currency, setCurrency] = useState(defaultCurrency)
  const [effectiveFrom, setEffectiveFrom] = useState(today())
  const [reason, setReason] = useState("merit")

  const mutation = useMutation({
    mutationFn: () =>
      recordSalaryChange(employeeId, {
        // Sent as a string, never a number. The backend refuses Floats for
        // money, and parsing to one here would defeat that at the boundary.
        amount: String(amount),
        currency,
        effective_from: effectiveFrom,
        change_reason: reason,
      }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["employee", employeeId] })
      await queryClient.invalidateQueries({ queryKey: ["employees"] })
      await queryClient.invalidateQueries({ queryKey: ["insights"] })
      setAmount("")
      onClose()
    },
  })

  return (
    <Modal opened={opened} onClose={onClose} title="Record a pay change" centered>
      <form
        onSubmit={(event) => {
          event.preventDefault()
          mutation.mutate()
        }}
      >
        <Stack gap="sm">
          {mutation.error && (
            <Alert color="red" variant="light" title="Change not recorded">
              {mutation.error.message}
            </Alert>
          )}

          <Group grow align="flex-start">
            <NumberInput
              label="New salary"
              placeholder="70000"
              value={amount}
              onChange={setAmount}
              min={0}
              decimalScale={2}
              thousandSeparator=","
              required
            />
            <Select
              label="Currency"
              data={reference?.currencies ?? [defaultCurrency]}
              value={currency}
              onChange={(value) => setCurrency(value ?? defaultCurrency)}
              allowDeselect={false}
            />
          </Group>

          <TextInput
            type="date"
            label="Effective from"
            value={effectiveFrom}
            max={today()}
            onChange={(event) => setEffectiveFrom(event.currentTarget.value)}
            description="The previous salary is closed on this date. Future dates are not accepted."
            required
          />

          <Select
            label="Reason"
            data={(reference?.change_reasons ?? []).map((value) => ({
              value,
              label: formatChangeReason(value),
            }))}
            value={reason}
            onChange={(value) => setReason(value ?? "merit")}
            allowDeselect={false}
          />

          <Group justify="flex-end" mt="xs">
            <Button variant="default" onClick={onClose} type="button">
              Cancel
            </Button>
            <Button type="submit" loading={mutation.isPending} disabled={amount === ""}>
              Record change
            </Button>
          </Group>
        </Stack>
      </form>
    </Modal>
  )
}
